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
| `make test` | 테스트 실행 | CI 재현 / 로컬 검증 |
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

# 스킴 이름이 기억 안 날 때 — 대화형으로 선택
make pick
```

> **`make pick`**: `xcodebuild -workspace … -list` 결과를 동적으로 읽어와 선택지를 띄웁니다.
> `fzf` 가 설치돼 있으면 fuzzy 검색, 없으면 bash `select` 로 번호 선택 메뉴가 뜹니다.
> 모듈을 추가/삭제해도 별도 동기화가 필요 없습니다.

### 사용 가능한 스킴 확인

```bash
xcodebuild -workspace UMCApp.xcworkspace -list
```

---

## 5. 버전 업그레이드 규칙

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

## 6. 트러블슈팅

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

## 7. 파일 구조 참고

```
UMCApp/
├── Makefile              # ← 이 가이드가 설명하는 파일
├── MAKEFILE_GUIDE.md     # ← 이 문서
├── mise.toml             # tuist 버전 고정
├── Tuist.swift
├── Workspace.swift
├── Project.swift
├── Tuist/
│   ├── Package.swift     # SPM 외부 의존성
│   └── ProjectDescriptionHelpers/
├── Core/                 # 공유 인프라 모듈
└── Features/             # 기능 모듈
```

모듈 구조 자체에 대한 설명은 루트 `CLAUDE.md` 의 **"Tuist 모듈 구조 (UMCApp)"** 섹션을 참고하세요.
