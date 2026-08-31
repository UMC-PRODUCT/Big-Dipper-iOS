#!/bin/sh
#
#  verify-secrets.sh
#  UMCApp
#
#  Created by euijjang97 on 8/13/26.
#

# UMCApp 앱 타겟의 Pre-action Run Script (Project.swift 의 scripts: 참고)
#
# 목적: 서드파티 시크릿이 빠진 채로 Release 빌드가 나가서 런타임에만 조용히 깨지는 상황을 막는다.
#   - Secrets.xcconfig 미주입 → KAKAO_KEY 가 빈 값 → URL Scheme 이 "kakao" 가 되어 카카오 로그인 실패
#   - GoogleService-Info.plist 부재 → configureFirebaseIfNeeded() 가 skip → FCM 푸시 사망
#
# 정책: Release 는 error(빌드 실패), Debug 는 warning 만 남기고 통과.
#       (신규 클론·CI 는 시크릿 없이도 빌드/테스트되어야 한다 — tuist-ci.yml)

set -eu

if [ "${CONFIGURATION:-Debug}" = "Release" ]; then
    LEVEL="error"
else
    LEVEL="warning"
fi

FAILED=0

report() {
    echo "${LEVEL}: $1"
    if [ "$LEVEL" = "error" ]; then
        FAILED=1
    fi
}

# MARK: - xcconfig 키 (Secrets/Shared.xcconfig ← Secrets/Secrets.xcconfig)

for key in KAKAO_KEY TMAP_SECRET_KEY GOOGLE_CLIENT_ID GOOGLE_REVERSED_CLIENT_ID; do
    eval "value=\${$key:-}"
    case "$value" in
        "")
            report "$key 가 비어 있습니다. UMCApp/Secrets/Secrets.xcconfig 를 확인하세요."
            ;;
        YOUR_*_HERE)
            report "$key 가 템플릿 플레이스홀더($value)입니다. 실제 값으로 교체하세요."
            ;;
    esac
done

# MARK: - Firebase 설정 파일

PLIST="${SRCROOT}/UMCApp/Resources/GoogleService-Info.plist"

if [ ! -f "$PLIST" ]; then
    report "GoogleService-Info.plist 가 없습니다 ($PLIST). Firebase 구성이 skip 되어 FCM 푸시가 죽습니다."
elif ! plutil -lint "$PLIST" >/dev/null 2>&1; then
    report "GoogleService-Info.plist 가 유효한 plist 가 아닙니다 ($PLIST)."
else
    APP_ID=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$PLIST" 2>/dev/null || true)
    case "$APP_ID" in
        "" | __*)
            report "GoogleService-Info.plist 의 GOOGLE_APP_ID 가 비었거나 플레이스홀더입니다. \
UMCAppApp.configureFirebaseIfNeeded() 가 Firebase 구성을 건너뜁니다."
            ;;
    esac
fi

if [ "$FAILED" = "1" ]; then
    echo "error: 필수 시크릿 누락으로 Release 빌드를 중단합니다. 수령·배치 방법은 UMCApp/Secrets/README.md 참고."
    exit 1
fi
