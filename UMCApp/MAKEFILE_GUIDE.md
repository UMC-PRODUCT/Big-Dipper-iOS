# UMCApp Makefile 사용 가이드

팀원 전원이 **동일한 Tuist 버전**으로 작업할 수 있도록 만든 래퍼입니다.
`mise.toml` 에 고정된 Tuist 버전을 `mise exec --` 로 감싸 실행합니다.

> 모든 명령은 `UMCApp/` 디렉터리에서 실행합니다.
> ```bash
> cd UMCApp
> ```

---

## 1. 최초 환경 구축 (신규 팀원용)

### Step 1. mise 설치 (이미 설치됐으면 생략)

```bash
brew install mise
```

설치 후 셸 설정(최초 1회):

```bash
# zsh
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc
```

공식 문서: https://mise.jdx.dev/getting-started.html

### Step 2. Tuist 설치 + 프로젝트 생성

```bash
cd UMCApp
make bootstrap   # mise.toml 기반으로 tuist 4.155.0 자동 설치
make install     # SPM 의존성 설치
make generate    # .xcworkspace / .xcodeproj 생성
make open        # Xcode 실행
```

이후 일상 작업은 **Step 2 만 반복**하면 됩니다.

---

## 2. 자주 쓰는 명령

| 명령 | 설명 | 언제 쓰나 |
|------|------|-----------|
| `make generate` | 워크스페이스 생성 | `Project.swift` / 모듈 구조 변경 후 |
| `make gen` | `generate` 별칭 | |
| `make open` | Xcode 워크스페이스 열기 (없으면 자동 generate) | 개발 시작할 때 |
| `make install` | SPM 의존성 설치 | `Tuist/Package.swift` 변경 후 |
| `make edit` | Tuist 매니페스트 편집 모드 | `Project+Feature.swift` 등 수정 시 |
| `make graph` | 의존성 그래프(`graph.png`) 생성 | 구조 리뷰할 때 |
| `make test` | 테스트 실행 (`SCHEME` = `UMCApp`) | CI 재현 / 로컬 검증 |
| `make test SCHEME=…` | 특정 스킴(모듈)만 테스트 | 한 모듈만 빠르게 검증할 때 |
| `make test-pick` | 스킴 목록에서 골라 테스트 (대화형) | 스킴 이름이 안 떠오를 때 |
| `make test-network` | CoreNetwork 단위+통합 테스트 (`TEST_SERVER_URL` 자동 전달) | 네트워크 레이어 변경 후 |
| `make build` | Debug 빌드 | 빌드 가능 여부만 확인할 때 |
| `make build SCHEME=…` | 특정 스킴(모듈)만 빌드 | 한 모듈만 빠르게 검증할 때 |
| `make pick` | 스킴 목록에서 골라 빌드 (대화형) | 스킴 이름이 안 떠오를 때 |
| `make doctor` | 환경 진단 (mise/tuist/xcode 버전) | 다른 팀원과 증상이 다를 때 |
| `make help` | 전체 타겟 목록 | 까먹었을 때 |

---

## 3. 정리 / 초기화

| 명령 | 설명 |
|------|------|
| `make clean` | `Derived/`, `Tuist/.build`, 생성된 `*.xcodeproj` / `*.xcworkspace`, `graph.*` 제거 |
| `make clean-dd` | 로컬 DerivedData (`.local-derived-data-*`) 제거 |
| `make reset` | `clean + clean-dd` 동시 실행 (전체 초기화) |

**초기화 후에는 반드시 `make generate` 를 다시 실행하세요.**

### 뭔가 꼬였을 때 복구 순서

```bash
make reset
make install
make generate
make open
```

---

## 4. 환경 변수 오버라이드

기본값은 Makefile 상단에 정의되어 있습니다. 필요 시 명령줄에서 덮어쓸 수 있습니다.

| 변수 | 기본값 | 예시 |
|------|--------|------|
| `SCHEME` | `UMCApp` | `make build SCHEME=AuthDomain` (모듈 단위 빌드) |
| `CONFIGURATION` | `Debug` | `make build CONFIGURATION=Release` |
| `DESTINATION` | `platform=iOS Simulator,name=iPhone 17 Pro` | `make test DESTINATION='platform=iOS Simulator,name=iPhone 17'` |
| `TEST_SERVER_URL` | `http://127.0.0.1:8080` | `make test-network TEST_SERVER_URL=http://127.0.0.1:9090` |

예시:

```bash
# Release 빌드
make build CONFIGURATION=Release

# 다른 시뮬레이터에서 테스트
make test DESTINATION='platform=iOS Simulator,name=iPhone 17'

# 특정 모듈만 빌드 (Tuist가 모듈마다 스킴을 자동 생성)
make build SCHEME=AuthDomain
make build SCHEME=NoticePresentation
make build SCHEME=CoreNetwork

# 특정 모듈만 테스트
make test SCHEME=AuthDomain
make test SCHEME=CoreNetwork

# 스킴 이름이 기억 안 날 때 — 대화형으로 선택
make pick        # 빌드용
make test-pick   # 테스트용
```

> **`make pick` / `make test-pick`**: `xcodebuild -workspace … -list` 결과를 동적으로 읽어와 선택지를 띄웁니다.
> `fzf` 가 설치돼 있으면 fuzzy 검색, 없으면 bash `select` 로 번호 선택 메뉴가 뜹니다.
> 모듈을 추가/삭제해도 별도 동기화가 필요 없습니다.

### 사용 가능한 스킴 확인

```bash
xcodebuild -workspace UMCApp.xcworkspace -list
```

---

## 5. CoreNetwork 통합 테스트

`CoreNetwork` 모듈은 두 단계로 검증됩니다.

| 계층 | 무엇 | 외부 의존 |
|------|------|----------|
| **단위 테스트** | URLProtocol 스텁 + actor Mock 으로 `NetworkClient`/`APIResponse`/`TokenPair` 검증 | 없음 — 항상 실행 |
| **통합 테스트** | 실제 Vapor 테스트 서버(`AppProductTestServer/`) 의 `/test`, `/protected`, `/auth/reissue` 호출 | 서버 살아있어야 실행 (없으면 자동 스킵) |

`make test-network` 한 번이면 두 계층이 동시에 돌아갑니다 — 통합 테스트는 `IntegrationConfig.isEnabled` 가 서버를 1.5초 ping 으로 감지해서 켜지므로 **서버를 띄워두고 돌리면 38개, 안 띄우면 31개** 가 통과합니다.

### 한 줄로 끝내기 (`make integration`)

레포 루트의 `AppProductTestServer/Makefile` 에 **start → UMCApp test-network → stop** 원샷이 있습니다.

```bash
cd AppProductTestServer
make integration   # 서버 자동 기동 → CoreNetwork 통합 테스트 → 서버 자동 종료
```

테스트가 실패해도 종료 단계는 항상 실행되며, 종료 코드는 보존됩니다 (CI 안전).

### 수동 흐름 (서버 띄워두고 반복 실행)

```bash
# 터미널 A — 서버 띄우기
cd AppProductTestServer
make start         # 백그라운드 + .server.pid / .server.log
make logs          # tail -f
make health        # / · /test · /protected 핑

# 터미널 B — 테스트 반복
cd UMCApp
make test-network  # 서버 살아있으면 통합도 자동 포함

# 끝
cd AppProductTestServer && make stop
```

### 환경 변수

| 변수 | 어디서 | 용도 |
|------|--------|------|
| `TEST_SERVER_URL` | `make test-network`, `make integration` | 테스트 코드(`IntegrationConfig.baseURL`) 가 읽는 베이스 URL |
| `HOST`, `PORT` | `AppProductTestServer/Makefile` | 서버 바인딩 (`make start HOST=0.0.0.0 PORT=9090`) |

### 트러블슈팅 — 포트 8080 점유

```bash
cd AppProductTestServer
make stop          # PID 파일 + pkill 패턴 + lsof 폴백 3중 종료
```

여전히 점유 중이면 `lsof -ti :8080 | xargs kill -9`.

---

## 6. 버전 업그레이드 규칙

Tuist 버전을 올릴 때는 **`mise.toml` 만** 수정합니다. Makefile은 건드리지 않습니다.

```toml
# UMCApp/mise.toml
[tools]
tuist = "4.155.0"   # ← 이 값만 변경
```

변경 후 팀원들은 각자:

```bash
cd UMCApp
make bootstrap    # 새 버전 자동 설치
make reset
make generate
```

버전 변경은 별도 PR로 올리고, PR 본문에 **릴리스 노트 링크**를 첨부하세요.

---

## 7. 트러블슈팅

### `mise: command not found`
→ `brew install mise` 후 셸 재시작.

### `tuist not found` (make 실행 시)
→ `make bootstrap` 다시 실행. 여전히 실패하면 `mise install` 로그 확인.

### `make generate` 후에도 Xcode가 옛 구조를 보임
→ `make reset && make generate`.

### 다른 팀원과 빌드 결과가 다름
→ `make doctor` 출력을 공유. `mise` / `tuist` / `Xcode` 버전이 일치하는지 확인.

### 워크스페이스가 이미 열려 있는 상태로 `make generate` 했더니 이상함
→ Xcode 완전 종료(⌘Q) → `make reset` → `make generate` → `make open`.

---

## 8. 파일 구조 참고

```
Big-Dipper-iOS/
├── UMCApp/
│   ├── Makefile              # ← 이 가이드가 설명하는 파일
│   ├── MAKEFILE_GUIDE.md     # ← 이 문서
│   ├── mise.toml             # tuist 버전 고정
│   ├── Tuist.swift
│   ├── Workspace.swift
│   ├── Project.swift
│   ├── Tuist/
│   │   ├── Package.swift     # SPM 외부 의존성
│   │   └── ProjectDescriptionHelpers/
│   ├── Core/                 # 공유 인프라 모듈
│   └── Features/             # 기능 모듈
└── AppProductTestServer/     # CoreNetwork 통합 테스트용 Vapor 서버
    ├── Makefile              # start / stop / integration 원샷
    └── Sources/AppProductTestServer/
```

모듈 구조 자체에 대한 설명은 루트 `CLAUDE.md` 의 **"Tuist 모듈 구조 (UMCApp)"** 섹션을 참고하세요.
