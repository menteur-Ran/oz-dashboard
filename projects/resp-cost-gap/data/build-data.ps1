# 대시보드 데이터 생성: SQL 덤프 -> data/dashboard-data.js
# 사용: powershell -ExecutionPolicy Bypass -File data\build-data.ps1 -SourceDir "<SQL 덤프 폴더>"
# 새 데이터가 오면 이 스크립트를 다시 실행하면 화면이 갱신된다.
param(
  [Parameter(Mandatory)][string]$SourceDir,
  [string]$OutFile
)
$ErrorActionPreference = 'Stop'
if (-not $OutFile) { $OutFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'dashboard-data.js' }
$enc = [Text.Encoding]::UTF8
$MIN_N = 30   # 이보다 작은 칸은 화면에서 "표본 부족"

# ---------- 01_setup: 환자, 기관, 코드표, 시도 ----------
$pat = @{}; $inst = @{}; $clName = @{}; $rgName = @{}
$rxP = [regex]"^\((\d+), '(\d)', (\d+), '(\d+)', '(\d)', (\d+|NULL)\)"
$rxI = [regex]"^\((\d+), '(\d+)', '(\d)', (?:'\d+'|NULL)\)"
$rxCl = [regex]"^\('종별코드', '(\w+)', '([^']+)'\)"
$rxSd = [regex]"^\('\d+', '[^']+', '(\d)', '([^']+)'\)"
foreach ($l in [IO.File]::ReadLines("$SourceDir\01_setup.sql", $enc)) {
  $m = $rxP.Match($l)
  if ($m.Success) {
    $g = $m.Groups
    $q = if ($g[5].Value -eq '3') { 'MA' } elseif ($g[6].Value -eq 'NULL') { 'NA' } else { 'Q' + $g[6].Value }
    $pat[[int]$g[1].Value] = $q; continue
  }
  $m = $rxI.Match($l)
  if ($m.Success) { $inst[[int]$m.Groups[1].Value] = @($m.Groups[2].Value, $m.Groups[3].Value); continue }
  $m = $rxCl.Match($l); if ($m.Success) { $clName[$m.Groups[1].Value] = $m.Groups[2].Value; continue }
  $m = $rxSd.Match($l); if ($m.Success) { $rgName[$m.Groups[1].Value] = $m.Groups[2].Value }
}

# ---------- 03_sick_master: 호흡기 상병명 ----------
$sickName = @{}
$rxS = [regex]"^\('(J\w+)', '([^']+)'"
foreach ($l in [IO.File]::ReadLines("$SourceDir\03_sick_master.sql", $enc)) {
  $m = $rxS.Match($l); if ($m.Success) { $sickName[$m.Groups[1].Value] = $m.Groups[2].Value }
}

# ---------- 02_claim ----------
$rxC = [regex]"^\((\d+), (\d+), (\d+), '(\d)', '(\d{3})', '([A-Z0-9]+)', (?:'[A-Z0-9]+'|NULL), '(\d+)', '(\d{4}-\d\d)-\d\d', '[\d-]+', (\d+), (\d+), (\d+), (\d+), (\d+), '(\d)', '(\d)'\)"
$all = 0; $resp = New-Object System.Collections.Generic.List[object]
$nonRespOut = New-Object System.Collections.Generic.List[object]
$ymMin = '9999-99'; $ymMax = '0000-00'
foreach ($l in [IO.File]::ReadLines("$SourceDir\02_claim.sql", $enc)) {
  if ($l.Length -lt 20 -or $l[0] -ne '(') { continue }
  $m = $rxC.Match($l); if (-not $m.Success) { throw "파싱 실패: $l" }
  $g = $m.Groups; $all++
  $ym = $g[8].Value; if ($ym -lt $ymMin) { $ymMin = $ym }; if ($ym -gt $ymMax) { $ymMax = $ym }
  $i = $inst[[int]$g[3].Value]
  $row = [pscustomobject]@{
    fom = $g[5].Value; sick = $g[6].Value; ym = $ym; amt = [long]$g[12].Value
    q = $pat[[int]$g[2].Value]; cl = $i[0]; rg = $i[1]
    inf = ($g[6].Value -match '^J(0\d|1\d|2[0-2])')
  }
  if ($g[6].Value[0] -eq 'J') { $resp.Add($row) } elseif ($row.fom -eq '031') { $nonRespOut.Add($row) }
}
$respOut = @($resp | Where-Object fom -eq '031')
$respIn = @($resp | Where-Object fom -eq '021')

function Med($a) { $s = @($a | Sort-Object); $n = $s.Count; if ($n -eq 0) { return $null }; if ($n % 2) { $s[($n-1)/2] } else { ($s[$n/2-1] + $s[$n/2]) / 2 } }
function Stat($rows) {
  $a = @($rows | ForEach-Object { $_.amt }); $n = $a.Count
  if ($n -eq 0) { return [ordered]@{ n = 0; mean = $null; median = $null } }
  [ordered]@{ n = $n; mean = [math]::Round(($a | Measure-Object -Average).Average); median = [math]::Round((Med $a)) }
}
$qOrder = 'Q1','Q2','Q3','Q4','Q5','MA'

# 소득 분위별
$quintile = foreach ($q in $qOrder) {
  $r = Stat ($respOut | Where-Object q -eq $q); $b = Stat ($nonRespOut | Where-Object q -eq $q)
  [ordered]@{ q = $q; n = $r.n; mean = $r.mean; median = $r.median; baseN = $b.n; baseMean = $b.mean; baseMedian = $b.median }
}

# 월별
$months = @($respOut + $respIn | ForEach-Object { $_.ym } | Sort-Object -Unique)
$monthly = foreach ($ym in $months) {
  $o = @($respOut | Where-Object ym -eq $ym)
  $q1 = Stat ($o | Where-Object q -eq 'Q1'); $q5 = Stat ($o | Where-Object q -eq 'Q5')
  [ordered]@{ ym = $ym; infN = @($o | Where-Object inf).Count; otherN = @($o | Where-Object { -not $_.inf }).Count
    q1N = $q1.n; q1Mean = $q1.mean; q5N = $q5.n; q5Mean = $q5.mean }
}

# 종별, 종별 x 권역
$classes = foreach ($gs in ($respOut | Group-Object cl | Sort-Object Name)) {
  $s = Stat $gs.Group
  [ordered]@{ cl = $gs.Name; name = $clName[$gs.Name]; n = $s.n; mean = $s.mean; median = $s.median }
}
$cells = foreach ($gs in ($respOut | Group-Object { $_.cl + '|' + $_.rg } | Sort-Object Name)) {
  $p = $gs.Name.Split('|'); $s = Stat $gs.Group
  [ordered]@{ cl = $p[0]; rg = $p[1]; n = $s.n; mean = $s.mean; median = $s.median }
}

# 상병별 (외래, 건수 상위 15)
$dx = foreach ($gs in ($respOut | Group-Object sick | Sort-Object Count -Descending | Select-Object -First 15)) {
  $o = [ordered]@{ code = $gs.Name; name = $sickName[$gs.Name]; inf = [bool]($gs.Group[0].inf); n = $gs.Count }
  foreach ($q in 'Q1','Q2','Q3','Q4','Q5') {
    $s = Stat ($gs.Group | Where-Object q -eq $q); $o["n$q"] = $s.n; $o["m$q"] = $s.mean
  }
  $o
}

$data = [ordered]@{
  meta = [ordered]@{ built = (Get-Date -Format 'yyyy-MM-dd'); minN = $MIN_N; periodFrom = $ymMin; periodTo = $ymMax
    claimsAll = $all; respAll = $resp.Count; respOut = $respOut.Count; respIn = $respIn.Count
    infShareOut = [math]::Round(@($respOut | Where-Object inf).Count / [math]::Max(1, $respOut.Count), 3) }
  regions = $rgName
  quintile = @($quintile); monthly = @($monthly); classes = @($classes); cells = @($cells); dx = @($dx)
}
$json = $data | ConvertTo-Json -Depth 6 -Compress
[IO.File]::WriteAllText($OutFile, "window.DASH = $json;`n", (New-Object Text.UTF8Encoding $false))
"완료: $OutFile  (명세서 $all, 호흡기 $($resp.Count), 외래 $($respOut.Count), 입원 $($respIn.Count))"
