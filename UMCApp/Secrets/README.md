# Secrets (xcconfig 기반 환경/시크릿 주입)

앱 타겟의 `BASE_URL`·`KAKAO_KEY`·`TMAP_SECRET_KEY` 를 빌드 설정(xcconfig) → `Info.plist` → `Config`(UMCFoundation) 경로로 주입합니다.

- 작성자: 제옹(euijjang97)

## 파일 구성

| 파일 | 배치 경로 | 커밋 | 역할 |
|------|-----------|------|------|
| `Shared.xcconfig` | `UMCApp/Secrets/` | ✅ | 앱 타겟이 참조하는 진입 xcconfig. 비밀이 아닌 기본값 + 환경별 `BASE_URL` 정의. 마지막에 `Secrets.xcconfig` 를 선택적 포함. |
| `Secrets.xcconfig.template` | `UMCApp/Secrets/` | ✅ | 로컬 시크릿 템플릿(플레이스홀더). |
| `Secrets.xcconfig` | `UMCApp/Secrets/` | ❌ (gitignore) | 개발자별 실제 키. `Shared.xcconfig` 기본값을 오버라이드. |
| `GoogleService-Info.plist` | `UMCApp/UMCApp/Resources/` | ❌ (gitignore) | Firebase(FCM 푸시·RemoteConfig) 설정. 없으면 `UMCAppApp.configureFirebaseIfNeeded()` 가 구성을 건너뛴다. |

두 시크릿 모두 **팀 공유 채널에서 수령**합니다. (`GoogleService-Info.plist` 는 Firebase 콘솔 →
프로젝트 설정 → iOS 앱 `com.umc.product` 에서도 내려받을 수 있습니다.)

## 최초 세팅

```bash
cd UMCApp/Secrets
cp Secrets.xcconfig.template Secrets.xcconfig
# Secrets.xcconfig 를 열어 팀 채널에서 받은 실제 값 입력
cd ..

# Firebase 설정 파일을 앱 리소스 폴더에 배치 (buildableFolders 로 자동 포함됨)
cp ~/Downloads/GoogleService-Info.plist UMCApp/Resources/

make generate
```

Debug 빌드는 두 파일이 없어도 통과합니다 — `Shared.xcconfig` 의 `#include?` 가 에러 없이 넘어가고
기본(dev) 값이 쓰이며, Firebase 는 구성 없이 fail-open 으로 동작합니다.

## 누락 가드 (Release 빌드 실패)

앱 타겟의 Pre-action Run Script `Scripts/verify-secrets.sh` (`Project.swift` 의 `scripts:`)가
빌드 시작 전에 아래를 검사합니다.

- `KAKAO_KEY` / `TMAP_SECRET_KEY` / `GOOGLE_CLIENT_ID` / `GOOGLE_REVERSED_CLIENT_ID` 가
  비었거나 템플릿 플레이스홀더(`YOUR_..._HERE`)인지
- `GoogleService-Info.plist` 존재 여부 · plist 유효성 · `GOOGLE_APP_ID` 가 플레이스홀더(`__`)가 아닌지

| Configuration | 동작 |
|---------------|------|
| `Release` | **`error:` 로 빌드 실패** — 키 없는 아카이브가 스토어로 나가는 것을 막는다. |
| `Debug` | `warning:` 만 출력하고 통과 — 신규 클론·CI 는 시크릿 없이도 빌드/테스트되어야 한다. |

시크릿이 없으면 카카오 로그인(URL Scheme 이 `kakao` 로 깨짐)·구글 로그인·TMap 지오코딩·FCM 푸시가
**빌드는 성공한 채 런타임에만** 죽기 때문에, 이 가드가 유일한 조기 경보입니다.

## 값이 흐르는 경로

```
Shared.xcconfig (+ Secrets.xcconfig 오버라이드)
   → Project.swift 앱 타겟 infoPlist: "$(BASE_URL)" 등 치환
   → Info.plist
   → Config.stringValue(for:) / Config.API.baseURL / Config.Auth.kakaoKey / Config.Map.tmapSecretKey
```

## 환경 분기

`BASE_URL[config=Debug]` / `BASE_URL[config=Release]` 로 빌드 Configuration 에 따라 서버가 자동 선택됩니다.

## CI

`.github/workflows/tuist-ci.yml` 이 클론 직후 두 파일을 UMCApp 경로에 주입합니다.

- `Secrets/Secrets.xcconfig` ← `Secrets.xcconfig.template` 복사 (플레이스홀더 값)
- `UMCApp/Resources/GoogleService-Info.plist` ← `secrets.GOOGLE_SERVICE_INFO_PLIST_BASE64` 디코드
  (시크릿 미설정 환경(fork PR 등)에서는 스킵)

CI 는 Debug 구성으로 빌드하므로 위 가드는 경고만 남깁니다. **Release 아카이브를 만드는 파이프라인
(Xcode Cloud `ci_post_clone` 등)에서는 실제 값을 주입해야 빌드가 통과합니다.** 레거시 스크립트
`AppProduct/ci_scripts/ci_post_clone.sh` 가 환경 변수 → xcconfig/plist 생성 로직의 참고 구현입니다
(경로만 `UMCApp/Secrets/`, `UMCApp/UMCApp/Resources/` 로 바꾸면 됩니다).

> xcconfig 에서 `//` 는 주석이므로 URL 은 `https:/$()/...` 형태로 escape 합니다.
