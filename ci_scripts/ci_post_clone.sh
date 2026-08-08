#!/bin/sh
#
# Xcode Cloud 가 저장소를 클론한 직후 자동 실행하는 스크립트.
#
# 이 저장소는 Tuist 프로젝트라 .xcworkspace / .xcodeproj 가 .gitignore 대상이다.
# 즉 클론 직후에는 Xcode 가 열 수 있는 프로젝트가 **없다** — 여기서 만들어 줘야
# 이어지는 Archive 액션이 동작한다.
#
# 실행 위치는 이 파일이 있는 ci_scripts 디렉터리이므로 저장소 루트로 먼저 이동한다.
# 로컬과 갈라지지 않게 명령은 전부 Makefile 을 거친다 (.github/workflows/ci.yml 과 같은 방침).

set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

# 러너에는 mise 가 없다. mise.toml 에 고정된 tuist 버전을 쓰기 위해 먼저 설치한다.
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
export MISE_YES=1
mise trust

make bootstrap   # mise.toml 의 tuist 설치
make generate    # secrets 타깃이 xcconfig 를 .example 에서 만들고, 워크스페이스를 생성

# xcconfig 는 generate 가 아니라 **빌드 시점**에 읽히므로 여기서 덧붙여도 늦지 않다.
# #include 뒤의 재할당이 이기므로 Hannun.shared.xcconfig 의 기본값을 덮어쓴다.
#   - CURRENT_PROJECT_VERSION: shared 의 1 을 CI 빌드 번호로 (같은 번호 재업로드는 거부된다)
#   - KIS_*: App Store Connect 워크플로의 Secret 환경변수. 미설정이면 빈 값으로 두고
#            사용자가 앱 안에서 직접 입력한다.
for config in debug release; do
    xcconfig="App/Config/Hannun.$config.xcconfig"
    echo "CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER:-1}" >> "$xcconfig"
    if [ -n "$KIS_APP_KEY" ]; then
        echo "KIS_APP_KEY = $KIS_APP_KEY" >> "$xcconfig"
    fi
    if [ -n "$KIS_APP_SECRET" ]; then
        echo "KIS_APP_SECRET = $KIS_APP_SECRET" >> "$xcconfig"
    fi
done
