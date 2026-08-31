#
#  Makefile
#  UMCApp
#
#  Created by euijjang97 on 4/24/26.
#

# UMCApp Tuist Makefile
#
# 팀 전원이 동일한 Tuist 버전(mise.toml 고정)으로 작업하기 위한 래퍼입니다.
# mise가 tuist 버전을 관리하므로, 모든 tuist 호출은 `mise exec --` 로 감쌉니다.
#
# 사용법:
#   cd UMCApp
#   make bootstrap   # 최초 1회: mise + tuist 설치
#   make generate    # 프로젝트 생성 (가장 자주 쓰는 커맨드)
#   make help        # 전체 타겟 목록

SHELL := /bin/bash
.DEFAULT_GOAL := help

SCHEME ?= UMCApp
WORKSPACE := UMCApp.xcworkspace
ROOT := ..
DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro
CONFIGURATION ?= Debug

WATCH_SCHEME ?= UMCWatchApp
# 워치 시뮬레이터 디바이스 목록은 머신마다 다르므로(로컬 Series 11 / CI 러너는 다른 세대)
# 디바이스명을 박으면 한쪽이 반드시 깨진다 → generic 목적지로 컴파일만 검증한다.
WATCH_DESTINATION ?= generic/platform=watchOS Simulator

MISE ?= mise
TUIST := $(MISE) exec -- tuist

# ──────────────────────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────────────────────

.PHONY: help
help: ## 이 도움말 출력
	@awk 'BEGIN {FS = ":.*?## "; printf "\nUMCApp Makefile — 사용 가능한 타겟:\n\n"} \
		/^[a-zA-Z_-]+:.*?## / { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""
	@echo "환경 변수 오버라이드 예시:"
	@echo "  make pick                                     # 스킴 골라서 빌드 (대화형)"
	@echo "  make test-pick                                # 스킴 골라서 테스트 (대화형)"
	@echo "  make build SCHEME=AuthDomain                  # 모듈 단위 빌드"
	@echo "  make test  SCHEME=AuthDomain                  # 모듈 단위 테스트"
	@echo "  make test  DESTINATION='platform=iOS Simulator,name=iPhone 17'"
	@echo "  make build CONFIGURATION=Release"
	@echo "  make build-watch                              # watchOS 앱 빌드 (generic 목적지)"
	@echo ""
	@echo "사용 가능한 스킴 목록:"
	@echo "  xcodebuild -workspace $(WORKSPACE) -list"
	@echo ""

##@ 환경 설정

.PHONY: bootstrap
bootstrap: check-mise ## 최초 환경 구축 (mise로 tuist 설치)
	@echo "▶︎ mise.toml 도구 설치 중..."
	@$(MISE) install
	@echo "▶︎ tuist 버전 확인"
	@$(TUIST) version
	@echo "bootstrap 완료. 이제 'make generate' 를 실행하세요."

.PHONY: check-mise
check-mise: ## mise 설치 여부 확인
	@if ! command -v $(MISE) >/dev/null 2>&1; then \
		echo "mise 가 설치되어 있지 않습니다."; \
		echo "설치: brew install mise"; \
		echo "셸 설정: https://mise.jdx.dev/getting-started.html"; \
		exit 1; \
	fi

.PHONY: doctor
doctor: check-mise ## 개발 환경 진단
	@echo "── mise ──"; $(MISE) --version
	@echo "── tuist ──"; $(TUIST) version
	@echo "── xcodebuild ──"; xcodebuild -version
	@echo "── mise.toml ──"; cat mise.toml

##@ Tuist

.PHONY: install
install: ## SPM 의존성 설치 (tuist install)
	@$(TUIST) install

.PHONY: generate
generate: ## 워크스페이스/프로젝트 생성
	@$(TUIST) generate --no-open

.PHONY: gen
gen: generate ## generate 별칭

.PHONY: generate-open
generate-open: ## 생성 후 Xcode로 열기
	@$(TUIST) generate

.PHONY: edit
edit: ## Tuist 매니페스트 편집 모드
	@$(TUIST) edit

.PHONY: graph
graph: ## 의존성 그래프(graph.png) 생성
	@$(TUIST) graph --format png --output-path .

.PHONY: cache-warm
cache-warm: ## Tuist 바이너리 캐시 워밍업
	@$(TUIST) cache

##@ 에셋

.PHONY: card-template
card-template: ## 3D 명함 베이스 USDZ 템플릿 재생성 (#1246 규약)
	@python3 $(ROOT)/tools/card-template/build_template.py

##@ Xcode

.PHONY: open
open: ## Xcode 워크스페이스 열기
	@if [ ! -d "$(WORKSPACE)" ]; then \
		echo "⚠️  $(WORKSPACE) 없음 → 먼저 'make generate' 실행"; \
		$(MAKE) generate; \
	fi
	@open $(WORKSPACE)

.PHONY: build
build: ## 빌드 ($(CONFIGURATION))
	@xcodebuild \
		-workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination "$(DESTINATION)" \
		build

.PHONY: build-watch
build-watch: ## watchOS 앱 빌드 ($(WATCH_SCHEME))
	@xcodebuild \
		-workspace $(WORKSPACE) \
		-scheme $(WATCH_SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination "$(WATCH_DESTINATION)" \
		build

.PHONY: pick
pick: ## 스킴을 골라 빌드 (fzf 있으면 fuzzy, 없으면 번호 선택)
	@if [ ! -d "$(WORKSPACE)" ]; then \
		echo "⚠️  $(WORKSPACE) 없음 → 먼저 'make generate' 실행"; \
		exit 1; \
	fi
	@SCHEMES=$$(xcodebuild -workspace $(WORKSPACE) -list 2>/dev/null \
		| awk '/Schemes:/{found=1; next} found && NF{sub(/^[[:space:]]+/, ""); print}'); \
	if [ -z "$$SCHEMES" ]; then \
		echo "스킴을 찾지 못했습니다."; exit 1; \
	fi; \
	if command -v fzf >/dev/null 2>&1; then \
		SCHEME=$$(echo "$$SCHEMES" | fzf --prompt="빌드할 스킴 > " --height=40% --reverse); \
	else \
		echo ""; \
		echo "빌드할 스킴을 선택하세요 (번호 입력, Ctrl+C 취소):"; \
		PS3="> "; \
		IFS=$$'\n'; \
		select s in $$SCHEMES; do \
			SCHEME=$$s; break; \
		done; \
	fi; \
	if [ -z "$$SCHEME" ]; then \
		echo "선택 취소"; exit 1; \
	fi; \
	echo "▶︎ '$$SCHEME' 빌드 시작"; \
	$(MAKE) build SCHEME="$$SCHEME"

.PHONY: test
test: ## 테스트 실행
	@xcodebuild \
		-workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination "$(DESTINATION)" \
		test

.PHONY: test-pick
test-pick: ## 스킴을 골라 테스트 (fzf 있으면 fuzzy, 없으면 번호 선택)
	@if [ ! -d "$(WORKSPACE)" ]; then \
		echo "⚠️  $(WORKSPACE) 없음 → 먼저 'make generate' 실행"; \
		exit 1; \
	fi
	@SCHEMES=$$(xcodebuild -workspace $(WORKSPACE) -list 2>/dev/null \
		| awk '/Schemes:/{found=1; next} found && NF{sub(/^[[:space:]]+/, ""); print}'); \
	if [ -z "$$SCHEMES" ]; then \
		echo "스킴을 찾지 못했습니다."; exit 1; \
	fi; \
	if command -v fzf >/dev/null 2>&1; then \
		SCHEME=$$(echo "$$SCHEMES" | fzf --prompt="테스트할 스킴 > " --height=40% --reverse); \
	else \
		echo ""; \
		echo "테스트할 스킴을 선택하세요 (번호 입력, Ctrl+C 취소):"; \
		PS3="> "; \
		IFS=$$'\n'; \
		select s in $$SCHEMES; do \
			SCHEME=$$s; break; \
		done; \
	fi; \
	if [ -z "$$SCHEME" ]; then \
		echo "선택 취소"; exit 1; \
	fi; \
	echo "▶︎ '$$SCHEME' 테스트 시작"; \
	$(MAKE) test SCHEME="$$SCHEME"

TEST_SERVER_URL ?= http://127.0.0.1:8080

.PHONY: test-network
test-network: ## CoreNetwork 단위+통합 테스트 (서버 살아있으면 통합도 자동 실행)
	@TEST_SERVER_URL="$(TEST_SERVER_URL)" xcodebuild \
		-workspace $(WORKSPACE) \
		-scheme CoreNetwork \
		-configuration $(CONFIGURATION) \
		-destination "$(DESTINATION)" \
		test

##@ 정리

.PHONY: clean
clean: ## Tuist Derived/빌드 산출물 제거
	@echo "▶︎ Tuist 생성물 제거"
	@rm -rf Derived
	@rm -rf */Derived
	@rm -rf */*/Derived
	@rm -rf Tuist/.build
	@rm -f graph.dot graph.png
	@echo "▶︎ 생성된 xcodeproj/xcworkspace 제거"
	@find . -maxdepth 3 -name "*.xcodeproj" -not -path "./Tuist/*" -exec rm -rf {} + 2>/dev/null || true
	@find . -maxdepth 3 -name "*.xcworkspace" -not -path "./Tuist/*" -exec rm -rf {} + 2>/dev/null || true
	@echo "clean 완료"

.PHONY: clean-dd
clean-dd: ## 로컬 DerivedData 제거
	@rm -rf .local-derived-data-*
	@echo "로컬 DerivedData 제거 완료"

.PHONY: reset
reset: clean clean-dd ## 전체 초기화 (clean + clean-dd)
	@echo "전체 리셋 완료. 'make generate' 로 다시 생성하세요."

## 제작자 : 제옹
