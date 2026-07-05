# Secrets (xcconfig 기반 환경/시크릿 주입)

앱 타겟의 `BASE_URL`·`KAKAO_KEY`·`TMAP_SECRET_KEY` 를 빌드 설정(xcconfig) → `Info.plist` → `Config`(UMCFoundation) 경로로 주입합니다.

## 파일 구성

| 파일 | 커밋 | 역할 |
|------|------|------|
| `Shared.xcconfig` | ✅ | 앱 타겟이 참조하는 진입 xcconfig. 비밀이 아닌 기본값 + 환경별 `BASE_URL` 정의. 마지막에 `Secrets.xcconfig` 를 선택적 포함. |
| `Secrets.xcconfig.template` | ✅ | 로컬 시크릿 템플릿(플레이스홀더). |
| `Secrets.xcconfig` | ❌ (gitignore) | 개발자별 실제 키. `Shared.xcconfig` 기본값을 오버라이드. |

## 최초 세팅

```bash
cd UMCApp/Secrets
cp Secrets.xcconfig.template Secrets.xcconfig
# Secrets.xcconfig 를 열어 팀 채널에서 받은 실제 값 입력
cd ..
make generate
```

`Secrets.xcconfig` 가 없어도 `Shared.xcconfig` 의 `#include?` 가 에러 없이 넘어가며 기본(dev) 값으로 빌드됩니다.

## 값이 흐르는 경로

```
Shared.xcconfig (+ Secrets.xcconfig 오버라이드)
   → Project.swift 앱 타겟 infoPlist: "$(BASE_URL)" 등 치환
   → Info.plist
   → Config.stringValue(for:) / Config.API.baseURL / Config.Auth.kakaoKey / Config.Map.tmapSecretKey
```

## 환경 분기

`BASE_URL[config=Debug]` / `BASE_URL[config=Release]` 로 빌드 Configuration 에 따라 서버가 자동 선택됩니다.

## CI (Xcode Cloud 등)

CI 에서는 `Secrets.xcconfig` 가 없으므로, `ci_post_clone` 단계에서 환경 변수로부터 `UMCApp/Secrets/Secrets.xcconfig` 를 생성하도록 스크립트를 추가하세요. (예: `KAKAO_KEY=$KAKAO_KEY` 등을 echo)

> xcconfig 에서 `//` 는 주석이므로 URL 은 `https:/$()/...` 형태로 escape 합니다.
