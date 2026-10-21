<#
.SYNOPSIS  template/ 을 복사해 projects/<Name>/ 을 만든다.
.EXAMPLE   .\new-project.ps1 -Name healthcare-sql -Title "AI 헬스케어 SQL 대시보드"
#>
param(
  [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._-]+$')][string]$Name,
  [string]$Title = $Name
)
$root = $PSScriptRoot
$dest = Join-Path $root "projects\$Name"
if (Test-Path $dest) { throw "이미 존재: $dest" }
Copy-Item (Join-Path $root 'template') $dest -Recurse
$date = Get-Date -Format 'yyyy-MM-dd'
Get-ChildItem $dest -Recurse -File -Include *.md,*.html | ForEach-Object {
  $t = [IO.File]::ReadAllText($_.FullName)
  $t = $t.Replace('{{PROJECT_NAME}}', $Title).Replace('{{DATE}}', $date)
  [IO.File]::WriteAllText($_.FullName, $t, (New-Object Text.UTF8Encoding $false))
}
Write-Host "생성됨: $dest"
