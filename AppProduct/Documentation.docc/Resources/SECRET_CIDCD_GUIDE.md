# 환경 변수 설정 가이드

- 작성자: 제옹(euijjang97)

## 로컬 개발 환경 설정

### 1. Secrets.xcconfig 파일 생성

```bash
# 템플릿 파일을 복사
cp Secrets.xcconfig.template Secrets.xcconfig
```

### 2. 실제 값 입력

`Secrets.xcconfig` 파일을 열어 다음 값들을 입력하세요:

```xcconfig
KAKAO_KEY=your_actual_kakao_app_key
BASE_URL=https:/$()/api.your-service.com
BASE_URL[config=Debug]=https:/$()/dev.api.your-service.com
BASE_URL[config=Release]=https:/$()/api.your-service.com
```

> 참고: `xcconfig`에서 `//`는 주석으로 처리되어 URL이 잘릴 수 있으므로 `https:/$()/...` 형식을 사용합니다.

### 3. Xcode 프로젝트에서 확인

- Xcode를 재시작하면 자동으로 환경 변수가 적용됩니다
- `Config.swift`에서 `Config.kakaoAppKey`, `Config.baseURL`로 접근 가능합니다

## CI/CD 환경 설정

### Xcode Cloud (App Store Connect)

1. **App Store Connect** 접속
2. 앱 선택 → **Xcode Cloud** 탭
3. **Environment Variables** 섹션에서 다음 변수 추가:

| 변수명 | 설명 | 예시 |
|--------|------|------|
| `KAKAO_KEY` | 카카오 앱 키 | `12344534523414151351231asdasdad` |
| `BASE_URL_DEBUG` | Debug API 서버 주소 | `https://dev.api.umc-product.com` |
| `BASE_URL_RELEASE` | Release API 서버 주소 | `https://api.umc-product.com` |
| `BASE_URL` | 레거시 단일 API 주소(선택) | `https://api.umc-product.com` |
| `TMAP_SECRET_KEY` | TMap Geocoding Secret Key | `your_tmap_secret_key` |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | `GoogleService-Info.plist`의 Base64 문자열 | `PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4...` |

4. 환경 변수는 `ci_scripts/ci_post_clone.sh`에서 자동으로 `Secrets.xcconfig`에 주입됩니다

5. Firebase 설정 파일(`GoogleService-Info.plist`)은 `GOOGLE_SERVICE_INFO_PLIST_BASE64`로 복원됩니다

### GoogleService-Info.plist Base64 생성 방법

로컬에서 아래 명령으로 Base64 문자열을 만든 뒤, App Store Connect의 Xcode Cloud 환경 변수에
`GOOGLE_SERVICE_INFO_PLIST_BASE64`로 등록하세요.

```bash
# macOS
base64 -i AppProduct/AppProduct/GoogleService-Info.plist | tr -d '\n'

# Linux
base64 -w 0 AppProduct/AppProduct/GoogleService-Info.plist
```

> 보안상 `GoogleService-Info.plist` 원본 파일은 저장소에 커밋하지 않고,
> Xcode Cloud 환경 변수로만 주입하는 방식을 권장합니다.

### GitHub Actions (선택 사항)

GitHub Actions를 사용하는 경우:

1. Repository **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret** 클릭
3. 다음 Secret 추가:
   - `KAKAO_KEY`
   - `BASE_URL_DEBUG`
   - `BASE_URL_RELEASE`
   - `BASE_URL` (선택, 하위 호환)
   - `TMAP_SECRET_KEY`
   - `GOOGLE_SERVICE_INFO_PLIST_BASE64`

## 보안 주의사항

⚠️ **중요**: `Secrets.xcconfig` 파일은 절대 Git에 커밋하지 마세요!

- ✅ `.gitignore`에 `Secrets.xcconfig` 포함됨
- ✅ `Secrets.xcconfig.template`만 Git에 커밋됨
- ❌ 실제 키 값이 담긴 `Secrets.xcconfig`는 커밋 금지

## 카카오 앱 키 발급

1. [Kakao Developers](https://developers.kakao.com/) 접속
2. 애플리케이션 생성 또는 선택
3. **앱 키** 탭에서 **네이티브 앱 키** 확인
4. `Secrets.xcconfig`에 키 값 입력

## 문제 해결

### "KakaoKey not found" 에러

- Xcode를 완전히 종료 후 재시작
- `Secrets.xcconfig` 파일이 올바른 경로에 있는지 확인:
  ```
  AppProduct/AppProduct/Core/Secret/Secrets.xcconfig
  ```

### CI 빌드 실패

- App Store Connect의 Environment Variables 설정 확인
- `ci_scripts/ci_post_clone.sh` 스크립트 로그 확인
