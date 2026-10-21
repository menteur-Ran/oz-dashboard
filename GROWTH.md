# 확장 규칙 (필요해질 때 한 층씩)
| 이런 일이 생기면 | 이렇게 늘림 |
|---|---|
| 지표 5개 초과 | `docs/metrics.md` 로 지표 정의 분리 |
| 화면 2개 이상 | `web/pages/` |
| 차트 3개 이상 | `web/components/` (차트 1개 = 파일 1개) |
| CSS·JS 길어짐 | `web/style.css`, `web/app.js` 분리 |
| 데이터 생성 명령 반복 | `data/queries/` + `scripts/` |
| 디자인 논의 발생 | `docs/design.md` |
| 설계 결정 누적 | `docs/decisions.md` |
| 배포·제출 | `dist/` (git 제외) |
