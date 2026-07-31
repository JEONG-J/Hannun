# Hannun Tuist Makefile
#
# 모듈(타깃) 단위로 빌드/테스트하기 위한 래퍼입니다.
# tuist 버전은 mise.toml 에 고정되어 있으므로 모든 tuist 호출을 `mise exec --` 로 감쌉니다.
#
# 사용법:
#   make bootstrap        # 최초 1회: mise.toml 도구(tuist) 설치
#   make generate         # 워크스페이스 생성 (가장 자주 쓰는 커맨드)
#   make build-domain     # HannunDomain 모듈만 빌드
#   make test-domain      # HannunDomain 모듈 테스트
#   make help             # 전체 타깃 목록
#
# 모듈-타깃 구성: docs/design/2026-07-30-tuist-module-target-spec.md

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
.DEFAULT_GOAL := help

# ──────────────────────────────────────────────────────────────
# 설정 (환경 변수로 오버라이드 가능)
# ──────────────────────────────────────────────────────────────

SCHEME        ?= Hannun
WORKSPACE     := Hannun.xcworkspace
DESTINATION   ?= platform=iOS Simulator,name=iPhone 17 Pro
CONFIGURATION ?= Debug

# 비우면 Xcode 공용 DerivedData 사용(증분 빌드 이득). 지정 시 프로젝트 로컬 경로 사용.
#   예) make build DERIVED_DATA=.derived-data
DERIVED_DATA  ?=

# `-only-testing:` 필터. Swift Testing 스위트/케이스 단위 실행에 사용.
#   예) make test-domain FILTER=HannunDomainTests/MoneyTests
FILTER        ?=

MISE  ?= mise
TUIST := $(MISE) exec -- tuist

# ── xcodebuild 공통 플래그 조립 ───────────────────────────────

ifneq ($(strip $(DERIVED_DATA)),)
DD_FLAG := -derivedDataPath $(DERIVED_DATA)
endif

ifneq ($(strip $(FILTER)),)
FILTER_FLAG := -only-testing:$(FILTER)
endif

# xcbeautify 가 설치되어 있으면 출력 포매팅 (없으면 원본 출력)
XCBEAUTIFY := $(shell command -v xcbeautify 2>/dev/null)
ifneq ($(strip $(XCBEAUTIFY)),)
XCPIPE := | $(XCBEAUTIFY)
endif

XCB = xcodebuild \
	-workspace $(WORKSPACE) \
	-configuration $(CONFIGURATION) \
	-destination "$(DESTINATION)" \
	$(DD_FLAG)

# ──────────────────────────────────────────────────────────────
# 모듈 ↔ 스킴 매핑 (설계 문서 §2 타깃 목록)
# ──────────────────────────────────────────────────────────────

MODULES := core design domain data networth portfolio performance journal testsupport app

SCHEME_core        := HannunCore
SCHEME_design      := HannunDesignSystem
SCHEME_domain      := HannunDomain
SCHEME_data        := HannunData
SCHEME_networth    := NetWorthFeature
SCHEME_portfolio   := PortfolioFeature
SCHEME_performance := PerformanceFeature
SCHEME_journal     := JournalFeature
SCHEME_testsupport := HannunTestSupport
SCHEME_app         := Hannun

# 테스트 타깃이 존재하는 모듈 (설계 문서 §6)
TESTABLE_MODULES := core domain data portfolio performance

# 의존 계층 순서 (L1 → L4)
LAYER_MODULES   := core design domain data
FEATURE_MODULES := networth portfolio performance journal

# ──────────────────────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────────────────────

.PHONY: help
help: ## 이 도움말 출력
	@awk 'BEGIN {FS = ":.*?## "; printf "\nHannun Makefile — 사용 가능한 타깃:\n"} \
		/^[a-zA-Z_][a-zA-Z0-9_-]*:.*?## / { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""
	@printf "\033[1m모듈 패턴 타깃\033[0m\n"
	@printf "  \033[36m%-18s\033[0m %s\n" "build-<모듈>" "해당 모듈만 빌드 (예: make build-domain)"
	@printf "  \033[36m%-18s\033[0m %s\n" "test-<모듈>" "해당 모듈 테스트 (예: make test-domain)"
	@echo ""
	@printf "\033[1m모듈 목록\033[0m  (모듈 → 스킴 / 테스트 타깃 유무)\n"
	@$(foreach m,$(MODULES),printf "  %-14s %-22s %s\n" "$(m)" "$(SCHEME_$(m))" \
		"$(if $(filter $(m),$(TESTABLE_MODULES)),테스트 O,테스트 없음)";)
	@echo ""
	@printf "\033[1m환경 변수 오버라이드 예시\033[0m\n"
	@echo "  make build SCHEME=HannunData                          # 스킴 직접 지정"
	@echo "  make test-domain FILTER=HannunDomainTests/MoneyTests   # 스위트 단위 실행"
	@echo "  make test DESTINATION='platform=iOS Simulator,name=iPhone 17'"
	@echo "  make build CONFIGURATION=Release"
	@echo "  make build-all DERIVED_DATA=.derived-data             # 로컬 DerivedData"
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
	@echo "── mise ──";       $(MISE) --version
	@echo "── tuist ──";      $(TUIST) version
	@echo "── xcodebuild ──"; xcodebuild -version
	@echo "── xcbeautify ──"; \
		if [ -n "$(XCBEAUTIFY)" ]; then echo "$(XCBEAUTIFY)"; \
		else echo "미설치 (선택 사항 — brew install xcbeautify 로 로그 가독성 향상)"; fi
	@echo "── mise.toml ──";  cat mise.toml
	@echo "── 매니페스트 ──"; \
		if [ -f Project.swift ]; then echo "Project.swift 있음"; \
		else echo "Project.swift 없음 (M0 스캐폴딩 미완료)"; fi
	@echo "── 워크스페이스 ──"; \
		if [ -d "$(WORKSPACE)" ]; then echo "$(WORKSPACE) 있음"; \
		else echo "$(WORKSPACE) 없음 → 'make generate'"; fi

##@ Tuist

.PHONY: install
install: check-manifest ## SPM 의존성 설치 (tuist install)
	@if [ -f Tuist/Package.swift ]; then \
		$(TUIST) install; \
	else \
		echo "외부 SPM 의존성 없음 — 건너뜁니다 (Tuist/Package.swift 미존재)"; \
	fi

.PHONY: generate
generate: check-manifest secrets ## 워크스페이스/프로젝트 생성
	@$(TUIST) generate --no-open

.PHONY: secrets
secrets: ## xcconfig 시크릿 파일을 .example 에서 생성 (없을 때만)
	@for cfg in debug release; do \
		dst="App/Config/Hannun.$$cfg.xcconfig"; \
		if [ ! -f "$$dst" ]; then \
			cp "$$dst.example" "$$dst"; \
			echo "생성: $$dst — KIS 앱키/시크릿을 채우세요 (설계 문서 §9.7)"; \
		fi; \
	done

.PHONY: inspect
inspect: check-manifest ## 암묵적 의존성 검사 (§3 금지 간선 차단)
	@$(TUIST) inspect dependencies --only implicit

.PHONY: gen
gen: generate ## generate 별칭

.PHONY: generate-open
generate-open: check-manifest ## 생성 후 Xcode로 열기
	@$(TUIST) generate

.PHONY: edit
edit: ## Tuist 매니페스트 편집 모드
	@$(TUIST) edit

.PHONY: graph
graph: check-manifest ## 의존성 그래프(graph.png) 생성
	@$(TUIST) graph --format png --output-path .

.PHONY: cache-warm
cache-warm: check-manifest ## Tuist 바이너리 캐시 워밍업
	@$(TUIST) cache

##@ Xcode

.PHONY: open
open: ## Xcode 워크스페이스 열기 (없으면 generate 먼저)
	@if [ ! -d "$(WORKSPACE)" ]; then \
		echo "⚠︎  $(WORKSPACE) 없음 → 'make generate' 실행"; \
		$(MAKE) --no-print-directory generate; \
	fi
	@open $(WORKSPACE)

.PHONY: schemes
schemes: check-workspace ## 워크스페이스의 스킴 목록 출력
	@xcodebuild -workspace $(WORKSPACE) -list

.PHONY: sims
sims: ## 사용 가능한 iOS 시뮬레이터 목록
	@xcrun simctl list devices available | sed -n '/-- iOS/,$$p'

.PHONY: build
build: check-workspace ## 빌드 (SCHEME 지정, 기본 Hannun)
	@echo "▶︎ build: $(SCHEME) [$(CONFIGURATION)]"
	@$(XCB) -scheme $(SCHEME) build $(XCPIPE)

.PHONY: test
test: check-workspace ## 테스트 (SCHEME 지정, 기본 Hannun)
	@echo "▶︎ test: $(SCHEME) [$(CONFIGURATION)]"
	@$(XCB) -scheme $(SCHEME) $(FILTER_FLAG) test $(XCPIPE)

.PHONY: pick
pick: check-workspace ## 스킴을 골라 빌드 (fzf 있으면 fuzzy, 없으면 번호 선택)
	@$(MAKE) --no-print-directory select-scheme ACTION=build

.PHONY: test-pick
test-pick: check-workspace ## 스킴을 골라 테스트 (fzf 있으면 fuzzy, 없으면 번호 선택)
	@$(MAKE) --no-print-directory select-scheme ACTION=test

##@ 모듈별 빌드 / 테스트

.PHONY: build-modules
build-modules: ## 앱 제외 전 모듈 빌드 (L1 → L4 → Feature 순)
	@for m in $(LAYER_MODULES) $(FEATURE_MODULES) testsupport; do \
		$(MAKE) --no-print-directory build-$$m || exit 1; \
	done

.PHONY: build-features
build-features: ## Feature 4종만 빌드
	@for m in $(FEATURE_MODULES); do \
		$(MAKE) --no-print-directory build-$$m || exit 1; \
	done

.PHONY: build-all
build-all: build-modules build-app ## 전 모듈 + 앱 빌드

.PHONY: test-all
test-all: check-workspace ## 전체 테스트 (Hannun 공용 스킴의 testAction)
	@echo "▶︎ test-all: Hannun 공용 스킴"
	@$(XCB) -scheme Hannun $(FILTER_FLAG) test $(XCPIPE)

.PHONY: test-modules
test-modules: ## 테스트 타깃이 있는 모듈을 하나씩 순차 테스트
	@for m in $(TESTABLE_MODULES); do \
		$(MAKE) --no-print-directory test-$$m || exit 1; \
	done

# build-<모듈> / test-<모듈> 패턴 규칙.
# 명시적 규칙(build-all, test-all 등)이 패턴 규칙보다 우선하므로 충돌하지 않는다.
# 워크스페이스 확인은 위임 대상인 build/test 가 담당한다 (모듈명 오타를 먼저 알려주기 위함).
build-%:
	@scheme="$(SCHEME_$*)"; \
	if [ -z "$$scheme" ]; then \
		echo "알 수 없는 모듈: '$*'"; \
		echo "사용 가능한 모듈: $(MODULES)"; \
		exit 1; \
	fi; \
	$(MAKE) --no-print-directory build SCHEME="$$scheme"

test-%:
	@scheme="$(SCHEME_$*)"; \
	if [ -z "$$scheme" ]; then \
		echo "알 수 없는 모듈: '$*'"; \
		echo "사용 가능한 모듈: $(MODULES)"; \
		exit 1; \
	fi; \
	if [ -z "$(filter $*,$(TESTABLE_MODULES))" ]; then \
		echo "'$*' 모듈에는 테스트 타깃이 없습니다."; \
		echo "테스트 가능한 모듈: $(TESTABLE_MODULES)"; \
		exit 1; \
	fi; \
	$(MAKE) --no-print-directory test SCHEME="$$scheme"

##@ CI

.PHONY: ci
ci: install generate build-all test-all ## CI 파이프라인 (install → generate → build → test)

##@ 정리

.PHONY: clean
clean: ## Tuist 생성물 / 빌드 산출물 제거
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
clean-dd: ## 프로젝트 로컬 DerivedData 제거
	@rm -rf .derived-data .derived-data-*
	@echo "로컬 DerivedData 제거 완료"

.PHONY: reset
reset: clean clean-dd ## 전체 초기화 (clean + clean-dd)
	@echo "전체 리셋 완료. 'make generate' 로 다시 생성하세요."

# ──────────────────────────────────────────────────────────────
# 내부 헬퍼 (help 에 노출하지 않음)
# ──────────────────────────────────────────────────────────────

.PHONY: check-manifest
check-manifest:
	@if [ ! -f Project.swift ]; then \
		echo "⚠︎  Project.swift 가 없습니다 — Tuist 매니페스트가 아직 작성되지 않았습니다."; \
		echo "   설계 문서의 §5(매니페스트) / §12(M0 착수 순서)를 참고해 스캐폴딩이 필요합니다:"; \
		echo "   docs/design/2026-07-30-tuist-module-target-spec.md"; \
		exit 1; \
	fi

.PHONY: check-workspace
check-workspace:
	@if [ ! -d "$(WORKSPACE)" ]; then \
		echo "⚠︎  $(WORKSPACE) 가 없습니다 → 먼저 'make generate' 를 실행하세요."; \
		if [ ! -f Project.swift ]; then \
			echo "   (Project.swift 도 없습니다. 설계 문서 §12 의 M0 스캐폴딩부터 필요합니다.)"; \
		fi; \
		exit 1; \
	fi

ACTION ?= build

.PHONY: select-scheme
select-scheme:
	@SCHEMES=$$(xcodebuild -workspace $(WORKSPACE) -list 2>/dev/null \
		| awk '/Schemes:/{found=1; next} found && NF{sub(/^[[:space:]]+/, ""); print}'); \
	if [ -z "$$SCHEMES" ]; then \
		echo "스킴을 찾지 못했습니다. 'make generate' 로 워크스페이스를 다시 생성해 보세요."; \
		exit 1; \
	fi; \
	if command -v fzf >/dev/null 2>&1; then \
		PICKED=$$(echo "$$SCHEMES" | fzf --prompt="$(ACTION) 할 스킴 > " --height=40% --reverse); \
	else \
		echo ""; \
		echo "$(ACTION) 할 스킴을 선택하세요 (번호 입력, Ctrl+C 취소):"; \
		PS3="> "; \
		IFS=$$'\n'; \
		select s in $$SCHEMES; do PICKED=$$s; break; done; \
	fi; \
	if [ -z "$$PICKED" ]; then echo "선택 취소"; exit 1; fi; \
	$(MAKE) --no-print-directory $(ACTION) SCHEME="$$PICKED"

## 제작자 : 제옹
