#!/bin/sh

set -e

echo "Starting ci_post_clone.sh script..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/.git" ]; do
  REPO_ROOT="$(dirname "$REPO_ROOT")"
done

if [ "$REPO_ROOT" = "/" ]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

WORKSPACE_ROOT="${CI_WORKSPACE:-$REPO_ROOT}"
echo "Using workspace root: $WORKSPACE_ROOT"

# Secrets.xcconfig 파일 생성 경로
CONFIG_PATH="${WORKSPACE_ROOT}/AppProduct/AppProduct/Core/Secret/Secrets.xcconfig"
# Firebase 설정 파일 복원 경로
FIREBASE_PLIST_PATH="${WORKSPACE_ROOT}/AppProduct/AppProduct/GoogleService-Info.plist"

echo "Creating Secrets.xcconfig at: $CONFIG_PATH"

# Core/Secret 디렉토리가 없을 경우 생성
mkdir -p "${WORKSPACE_ROOT}/AppProduct/AppProduct/Core/Secret"

# base64 디코드 호환 함수 (macOS: -D, GNU: --decode)
decode_base64() {
  input="$1"

  if printf "%s" "$input" | base64 --decode >/dev/null 2>&1; then
    printf "%s" "$input" | base64 --decode
    return 0
  fi

  if printf "%s" "$input" | base64 -D >/dev/null 2>&1; then
    printf "%s" "$input" | base64 -D
    return 0
  fi

  return 1
}

# BASE_URL 하위 호환:
# - 권장: BASE_URL_DEBUG / BASE_URL_RELEASE
# - 레거시: BASE_URL (둘 다 동일 값으로 사용)
BASE_URL_DEBUG_VALUE="${BASE_URL_DEBUG:-${BASE_URL}}"
BASE_URL_RELEASE_VALUE="${BASE_URL_RELEASE:-${BASE_URL}}"

if [ -z "$BASE_URL_DEBUG_VALUE" ] || [ -z "$BASE_URL_RELEASE_VALUE" ]; then
  echo "ERROR: BASE_URL_DEBUG/BASE_URL_RELEASE (or BASE_URL) environment variables are required."
  exit 1
fi

if [ -z "$KAKAO_KEY" ]; then
  echo "ERROR: KAKAO_KEY environment variable is required."
  exit 1
fi

if [ -z "$TMAP_SECRET_KEY" ]; then
  echo "ERROR: TMAP_SECRET_KEY environment variable is required."
  exit 1
fi

# Google OAuth (iOS Google Sign-In)
# - GOOGLE_CLIENT_ID 필수 (예: 6550...-xxxx.apps.googleusercontent.com)
# - GOOGLE_REVERSED_CLIENT_ID 미지정 시 CLIENT_ID에서 자동 도출
#   (com.googleusercontent.apps.<unique>)
if [ -z "$GOOGLE_CLIENT_ID" ]; then
  echo "ERROR: GOOGLE_CLIENT_ID environment variable is required."
  exit 1
fi

GOOGLE_REVERSED_CLIENT_ID_VALUE="${GOOGLE_REVERSED_CLIENT_ID:-}"
if [ -z "$GOOGLE_REVERSED_CLIENT_ID_VALUE" ]; then
  GOOGLE_CLIENT_ID_UNIQUE="$(printf "%s" "$GOOGLE_CLIENT_ID" | sed 's/\.apps\.googleusercontent\.com$//')"
  GOOGLE_REVERSED_CLIENT_ID_VALUE="com.googleusercontent.apps.${GOOGLE_CLIENT_ID_UNIQUE}"
fi

# xcconfig에서는 '//'가 주석이므로 URL을 https:/$()/... 형식으로 변환
to_xcconfig_url() {
  printf "%s" "$1" | sed 's#://#:/$()/#'
}

BASE_URL_DEBUG_XCCONFIG="$(to_xcconfig_url "$BASE_URL_DEBUG_VALUE")"
BASE_URL_RELEASE_XCCONFIG="$(to_xcconfig_url "$BASE_URL_RELEASE_VALUE")"

# App Store Connect에 등록한 환경 변수로 xcconfig 생성
cat > "$CONFIG_PATH" << EOF
KAKAO_KEY=${KAKAO_KEY}
BASE_URL=${BASE_URL_RELEASE_XCCONFIG}
BASE_URL[config=Debug]=${BASE_URL_DEBUG_XCCONFIG}
BASE_URL[config=Release]=${BASE_URL_RELEASE_XCCONFIG}
TMAP_SECRET_KEY=${TMAP_SECRET_KEY}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_REVERSED_CLIENT_ID=${GOOGLE_REVERSED_CLIENT_ID_VALUE}
EOF

echo "Secrets.xcconfig created successfully"
echo "Secrets.xcconfig created successfully at: $CONFIG_PATH"

if ! grep -q '^KAKAO_KEY=' "$CONFIG_PATH" \
  || ! grep -q '^TMAP_SECRET_KEY=' "$CONFIG_PATH" \
  || ! grep -q '^GOOGLE_CLIENT_ID=' "$CONFIG_PATH" \
  || ! grep -q '^GOOGLE_REVERSED_CLIENT_ID=' "$CONFIG_PATH"; then
  echo "ERROR: Secrets.xcconfig validation failed (missing required keys)"
  exit 1
fi

# Firebase GoogleService-Info.plist 복원
# - 권장: GOOGLE_SERVICE_INFO_PLIST_BASE64
# - 대안: GOOGLE_SERVICE_INFO_PLIST_CONTENT (raw xml)
if [ -n "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ]; then
  echo "Restoring GoogleService-Info.plist from GOOGLE_SERVICE_INFO_PLIST_BASE64..."
  if ! decode_base64 "$GOOGLE_SERVICE_INFO_PLIST_BASE64" > "$FIREBASE_PLIST_PATH"; then
    echo "ERROR: Failed to decode GOOGLE_SERVICE_INFO_PLIST_BASE64"
    exit 1
  fi
elif [ -n "$GOOGLE_SERVICE_INFO_PLIST_CONTENT" ]; then
  echo "Restoring GoogleService-Info.plist from GOOGLE_SERVICE_INFO_PLIST_CONTENT..."
  printf "%s" "$GOOGLE_SERVICE_INFO_PLIST_CONTENT" > "$FIREBASE_PLIST_PATH"
else
  echo "ERROR: Firebase config is required. Set GOOGLE_SERVICE_INFO_PLIST_BASE64 in Xcode Cloud environment variables."
  exit 1
fi

if ! grep -q "<plist" "$FIREBASE_PLIST_PATH"; then
  echo "ERROR: Restored GoogleService-Info.plist does not look like a plist file."
  exit 1
fi

if ! plutil -lint "$FIREBASE_PLIST_PATH" >/dev/null 2>&1; then
  echo "ERROR: GoogleService-Info.plist is not a valid plist file."
  exit 1
fi

if ! grep -q "<key>GOOGLE_APP_ID</key>" "$FIREBASE_PLIST_PATH"; then
  echo "ERROR: GOOGLE_APP_ID missing in GoogleService-Info.plist."
  exit 1
fi

echo "GoogleService-Info.plist restored successfully at: $FIREBASE_PLIST_PATH"
