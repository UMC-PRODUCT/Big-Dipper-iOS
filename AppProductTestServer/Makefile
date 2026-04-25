# AppProductTestServer Makefile
#
# CoreNetwork / 앱 통합 테스트용 로컬 Vapor 서버를 손쉽게 띄우고 내릴 수 있는 래퍼입니다.
# 별도 PostgreSQL 없이도 정의된 라우트는 모두 동작합니다 (라우트가 DB를 사용하지 않음).

HOST    ?= 127.0.0.1
PORT    ?= 8080
PIDFILE := .server.pid
LOGFILE := .server.log

.PHONY: help build run start stop restart logs status health clean test integration

help: ## 사용 가능한 타겟 목록 표시
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS=":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## swift build (Debug)
	swift build

run: ## 포그라운드로 서버 실행 (Ctrl+C로 종료)
	swift run AppProductTestServer serve --hostname $(HOST) --port $(PORT)

start: ## 백그라운드로 서버 실행
	@if [ -f $(PIDFILE) ] && kill -0 $$(cat $(PIDFILE)) 2>/dev/null; then \
	  echo "이미 실행 중 (PID: $$(cat $(PIDFILE)))"; \
	else \
	  swift build > /dev/null && \
	  nohup swift run AppProductTestServer serve --hostname $(HOST) --port $(PORT) \
	    > $(LOGFILE) 2>&1 & echo $$! > $(PIDFILE); \
	  sleep 2; \
	  echo "서버 시작 (PID: $$(cat $(PIDFILE))) — http://$(HOST):$(PORT)"; \
	fi

stop: ## 백그라운드 서버 종료
	@-pkill -9 -f "AppProductTestServer.*serve" 2>/dev/null || true
	@-pkill -9 -f "AppProductTestServer/debug/AppProductTestServer" 2>/dev/null || true
	@if [ -f $(PIDFILE) ]; then kill -9 $$(cat $(PIDFILE)) 2>/dev/null || true; rm -f $(PIDFILE); fi
	@if lsof -i :$(PORT) >/dev/null 2>&1; then \
	  echo "포트 $(PORT) 점유 프로세스 강제 종료"; \
	  lsof -ti :$(PORT) | xargs kill -9 2>/dev/null || true; \
	fi
	@echo "서버 종료"

restart: stop start ## 서버 재시작

logs: ## 백그라운드 서버 로그 tail
	@if [ -f $(LOGFILE) ]; then tail -f $(LOGFILE); else echo "$(LOGFILE) 없음 — make start 먼저"; fi

status: ## 서버 상태 확인
	@if [ -f $(PIDFILE) ] && kill -0 $$(cat $(PIDFILE)) 2>/dev/null; then \
	  echo "✅ 실행 중 (PID: $$(cat $(PIDFILE))) — http://$(HOST):$(PORT)"; \
	else \
	  echo "❌ 실행 중 아님"; \
	fi

health: ## 주요 엔드포인트 핑 (서버 살아있는지 확인)
	@echo "GET / →" && curl -sf http://$(HOST):$(PORT)/ && echo
	@echo "GET /test →" && curl -sf http://$(HOST):$(PORT)/test && echo
	@echo "GET /protected (Bearer A) →" \
	  && curl -sf -H "Authorization: Bearer A" http://$(HOST):$(PORT)/protected && echo

test: ## swift test
	swift test

clean: stop ## 서버 종료 + 빌드/로그 정리
	rm -f $(PIDFILE) $(LOGFILE)
	swift package clean

integration: ## 서버 start → UMCApp CoreNetwork 통합 테스트 → 서버 stop (원샷)
	@$(MAKE) start
	@echo "▶︎ CoreNetwork 통합 테스트 실행 (TEST_SERVER_URL=http://$(HOST):$(PORT))"
	@cd ../UMCApp && $(MAKE) test-network TEST_SERVER_URL=http://$(HOST):$(PORT); STATUS=$$?; \
	  cd ../AppProductTestServer && $(MAKE) stop; \
	  exit $$STATUS
