# OZ Dashboard

대시보드 프로젝트를 같은 구조로 반복 생성하는 작업 공간.

- `template/` — 1단계 뼈대 (4개: README.md, docs/, data/, web/)
- `GROWTH.md` — 폴더를 늘리는 규칙 (필요해질 때 한 층씩)
- `new-project.ps1` — 템플릿 복사 + 이름/날짜 치환
- `projects/` — 생성된 프로젝트들

```powershell
.\new-project.ps1 -Name 새프로젝트 -Title "화면 제목"
```
