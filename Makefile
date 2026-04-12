# https://makefiletutorial.com/
MAKEFLAGS += --no-print-directory
SHELL:=/bin/bash
# colours
RED:=\033[31m
RED_BOLD=\033[1;31m
BLUE:=\033[34m
BLUE_BOLD=\033[1;34m
GREEN:=\033[32m
GREEN_BOLD=\033[1;32m
YELLOW:=\033[133m
YELLOW_BOLD=\033[1;33m
RESET:=\033[0m

# auto-detect source directory (./code or ./src)
APP_SRC_DIR := $(shell if [ -d "./code" ]; then echo "code"; elif [ -d "./src" ]; then echo "src"; else echo "src"; fi)
COMPOSE_FILE := ./$(APP_SRC_DIR)/docker-compose.yml

# HTTP port — used by compose generators; read from env with fallback to 3000
HTTP_PORT := $(or $(PORT),$(subst ",,$(K8S_CONTAINER_PORTS)),3000)

.ONESHELL:
SRC := $(shell \
  os=$$(hostname); \
	branch=$$(git rev-parse --abbrev-ref HEAD); \
	if [[ $$branch == "bams" ]]; then \
		cp ./ops/bams.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == "release/dev" ]]; then \
		cp ./ops/dev.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == "release/dev-v2" ]]; then \
		cp ./ops/dev-v2.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == "release/prev" ]]; then \
		cp ./ops/prev.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == "release/prev-v2" ]]; then \
		cp ./ops/prev-v2.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == "release/prod" ]]; then \
		cp ./ops/prod.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == "release/prod-v2" ]]; then \
		cp ./ops/prod-v2.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == "v1" ]]; then \
		cp ./ops/v1.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == dev-* ]]; then \
		cp ./ops/$$branch.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == release/dev-* ]]; then \
		env_name=$${branch#release/}; \
		cp ./ops/$$env_name.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == prev-* ]]; then \
		cp ./ops/$$branch.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == release/prev-* ]]; then \
		env_name=$${branch#release/}; \
		cp ./ops/$$env_name.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == prod-* ]]; then \
		cp ./ops/$$branch.env ./$(APP_SRC_DIR)/.env; \
	elif [[ $$branch == release/prod-* ]]; then \
		env_name=$${branch#release/}; \
		cp ./ops/$$env_name.env ./$(APP_SRC_DIR)/.env; \
	else \
		cp ./ops/bams.env ./$(APP_SRC_DIR)/.env; \
	fi; \
  if [[ $$branch != "bams" ]] && [[ -f ./ops/sh/app.sh ]]; then chmod +x ./ops/sh/app.sh; fi)

all: mk

# load env file
include ./$(APP_SRC_DIR)/.env

# load makefiles
include ./ops/mk/0-init.mk
include ./ops/mk/1-build.mk
include ./ops/mk/2-push.mk
include ./ops/mk/3-run.mk
include ./ops/mk/4-utils.mk

# remove double quotes from variable
DL_APP_STACK := $(subst ",,${DL_APP_STACK})

# include app stack
ifeq ($(DL_APP_STACK),laravel)
	include ./ops/mk/laravel.mk
endif

mk:
	@echo ""

0:
	@chmod +x ./ops/sh/app.sh
	@./ops/sh/app.sh

# CI/CD Pipeline Management
setup-pipeline:
	@echo -e "${BLUE_BOLD}🚀 Setting up CI/CD Pipeline${RESET}"
	@chmod +x ./ops/sh/setup-pipeline.sh
	@./ops/sh/setup-pipeline.sh

install-hooks:
	@echo -e "${BLUE_BOLD}🔧 Installing Git Hooks${RESET}"
	@chmod +x ./ops/sh/install-hooks.sh
	@./ops/sh/install-hooks.sh

auto-version:
	@echo -e "${BLUE_BOLD}🏷️ Generating Auto Version${RESET}"
	@chmod +x ./ops/sh/auto-version.sh
	@./ops/sh/auto-version.sh $(BRANCH)

add-kubeconfig:
	@echo -e "${BLUE_BOLD}🔧 Adding Kubernetes Config to Vault${RESET}"
	@chmod +x ./ops/sh/add-kubeconfig.sh
	@./ops/sh/add-kubeconfig.sh

update-version:
	@echo -e "${BLUE_BOLD}🔄 Updating Environment Version${RESET}"
	@chmod +x ./ops/sh/update-env-version.sh
	@./ops/sh/update-env-version.sh $(ENV_FILE) $(VERSION)

upload-secrets:
	@echo -e "${BLUE_BOLD}🔐 Uploading Secrets to Vault${RESET}"
	@chmod +x ./ops/sh/vault.sh
	@./ops/sh/vault.sh $(ENV_FILE)

gh-vault:
	@echo -e "${BLUE_BOLD}🔐 Setting VAULT_URL and VAULT_TOKEN as GitHub secrets${RESET}"
	@chmod +x ./ops/sh/app.sh
	@./ops/sh/app.sh 34

show-versions:
	@echo -e "${BLUE_BOLD}📋 Current Versions${RESET}"
	@echo -e "${YELLOW}===================${RESET}"
	@if [ -f .version ]; then \
		while IFS= read -r line; do \
			echo -e "${GREEN}  $$line${RESET}"; \
		done < .version; \
	else \
		echo -e "${RED}  No .version file found${RESET}"; \
	fi
	@echo -e "${YELLOW}===================${RESET}"

# Main deployment targets
init: init-app

app: build-app

push: deploy-app

dpl: deploy

run: run-app

utils: app-utils
