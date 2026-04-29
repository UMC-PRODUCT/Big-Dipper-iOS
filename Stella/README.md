# Stella

UMC PRODUCT API와 iOS 코드베이스(`AppProduct/`, `UMCApp/`)의 Moya Router 연결 상태를 추적하는 SwiftPM 도구입니다.

## Build

```bash
cd Stella
swift build
```

## Scan

```bash
export UMC_API_USER=...
export UMC_API_PASS=...

swift run apicov scan \
  --openapi-url https://dev.api.umc.it.kr/docs-json \
  --auth-env UMC_API_USER:UMC_API_PASS \
  --app-product ../AppProduct \
  --umc-app ../UMCApp \
  --blame-root .. \
  --authors authors.yml \
  --overrides overrides.yml \
  --owners owners.yml \
  --out coverage.json
```

`--openapi-file`을 사용하면 이미 받은 OpenAPI JSON으로 스캔할 수 있습니다.

```bash
swift run apicov scan \
  --openapi-file /tmp/openapi.json \
  --app-product ../AppProduct \
  --umc-app ../UMCApp \
  --blame-root .. \
  --out coverage.json
```

## Diff

```bash
swift run apicov diff old-coverage.json new-coverage.json
```

## Report (HTML)

```bash
swift run apicov report coverage.json --out coverage.html
```

`--out` 을 생략하면 stdout 으로 HTML 을 흘려줍니다. 결과 페이지에는 프로젝트별 요약, 담당자 롤업, 엔드포인트 테이블, 매치 안 된 라우터 케이스가 포함됩니다.

## App (macOS GUI)

```bash
swift run stella
```

GUI 에서 담당자를 지정한 뒤 메뉴 **File → owners.yml 저장…** (⇧⌘S) 으로 `owners.yml` 로 내보낼 수 있습니다. 기존 파일이 있으면 `tags:` 섹션은 보존되고 `endpoints:` 섹션만 GUI 매핑으로 덮어쓰여집니다. 파일을 git 에 커밋해야 팀원/CI 가 볼 수 있습니다.

**우선순위**: scan 또는 snapshot 로드 시점에 `owners.yml` 의 매핑이 본인 GUI(UserDefaults)를 자동으로 동기화·덮어씁니다. 즉 yml 이 진실의 원천이고, GUI 에서의 변경은 ⇧⌘S 로 yml 에 commit 하기 전까지는 "pending" 상태입니다. 다시 scan 을 돌리면 미저장 GUI 변경은 yml 값으로 되돌아갑니다.

### `.app` 번들로 패키징

```bash
scripts/build-app.sh
open "dist/Stella.app"
```

`dist/Stella.app` 이 생성되며 Finder에서 더블클릭 / Applications 로 드래그 가능. ad-hoc 서명만 들어가므로 다른 맥에서 처음 열 때는 우클릭 → 열기 가 필요합니다 (정식 배포에는 Apple Developer ID 서명 + notarization 별도 필요).

`--no-build` 플래그로 기존 release 빌드 산출물을 재사용할 수 있습니다.

## Mapping

- `overrides.yml` — 자동 매칭 실패 케이스 보정
- `authors.yml` — 작성자 표시명·GitHub username
- `owners.yml` — 엔드포인트별/태그별 담당자 (이메일 → `authors.yml` 의 displayName 으로 해석)

각 파일은 `*.example` 템플릿을 복사해 사용하면 됩니다.

스냅샷 JSON 스키마는 `Sources/StellaCore/Snapshot/CoverageSnapshot.swift` 를 기준으로 합니다.

## CI / GitHub Pages

`.github/workflows/api-coverage.yml` 이 매주 월요일 00:00 UTC, `develop` 푸시(스캐너·라우터 변경 시), `workflow_dispatch` 에서 실행됩니다.

워크플로 동작:

1. `swift build -c release --product apicov`
2. `apicov scan` 으로 `coverage.json` 생성 (`UMC_API_USER` / `UMC_API_PASS` secrets 사용)
3. `apicov report` 로 `_site/index.html` 렌더링
4. `coverage-snapshot` 아티팩트 업로드 + GitHub Pages 배포

### 사전 작업

- 레포 Settings → Secrets and variables → Actions 에 `UMC_API_USER` / `UMC_API_PASS` 등록
- Settings → Pages 에서 source 를 **GitHub Actions** 로 설정
- (선택) 실제 `authors.yml` / `overrides.yml` / `owners.yml` 을 레포에 커밋하면 자동으로 픽업됩니다. 파일이 없으면 해당 옵션은 자동 생략됩니다.
