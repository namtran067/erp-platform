# ============================================================================
# Common commands for the ERP (Frappe + ERPNext v16) meta-repo.
#
# IMPORTANT: on this host the `docker compose` v2 plugin is broken (dangling
# Docker.app symlinks), but the standalone `docker-compose` (Homebrew) works.
# So every target below uses `docker-compose` (hyphen).
#
# Quick start:
#   make dev-up        - start dev containers
#   make dev-init      - create bench + site + install erpnext (idempotent)
#   make dev-start     - run the bench dev server (blocks)
#   make SITE=development.localhost dev-migrate
# ============================================================================

SITE        ?= development.localhost
APP_NAME    ?= custom_app
IMAGE       ?= my-erpnext
TAG         ?= v16-custom

COMPOSE_DEV  := docker-compose -f dev/docker-compose.yml
COMPOSE_PROD := docker-compose -f prod/docker-compose.yml

.PHONY: help \
        dev-up dev-down dev-restart dev-init dev-start dev-shell \
        new-app dev-install-app dev-build-app dev-build-assets dev-migrate dev-clear-cache \
        build-prod prod-up prod-down prod-restart prod-new-site prod-migrate \
        update-upstream push

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m [VAR=value]\n\nTargets:\n"} \
/^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ------------------------------ DEV ---------------------------------
dev-up: ## Start dev containers (mariadb, redis, frappe)
	$(COMPOSE_DEV) up -d

dev-down: ## Stop dev containers
	$(COMPOSE_DEV) down

dev-restart: dev-down dev-up ## Restart dev containers

dev-init: ## Create bench + first site + install erpnext (idempotent)
	$(COMPOSE_DEV) exec frappe bash /workspace/dev/init.sh

dev-start: ## Run the bench dev server (blocks, shows logs)
	$(COMPOSE_DEV) exec frappe bash -lc "cd /workspace/frappe-bench && bench start"

dev-shell: ## Open a shell in the frappe container
	$(COMPOSE_DEV) exec frappe bash

new-app: ## Create a custom app: make new-app APP_NAME=my_app
	$(COMPOSE_DEV) exec frappe bash /workspace/dev/new-custom-app.sh $(APP_NAME)

dev-install-app: ## Install an app on the site: make dev-install-app APP_NAME=custom_app
	$(COMPOSE_DEV) exec frappe bash -lc "cd /workspace/frappe-bench && bench --site $(SITE) install-app $(APP_NAME)"

dev-build-app: ## Build assets for one app: make dev-build-app APP_NAME=custom_app
	$(COMPOSE_DEV) exec frappe bash -lc "cd /workspace/frappe-bench && bench build --app $(APP_NAME)"

dev-build-assets: ## Build assets for ALL apps
	$(COMPOSE_DEV) exec frappe bash -lc "cd /workspace/frappe-bench && bench build"

dev-migrate: ## Run migrations on the site
	$(COMPOSE_DEV) exec frappe bash -lc "cd /workspace/frappe-bench && bench --site $(SITE) migrate"

dev-clear-cache: ## Clear the site cache
	$(COMPOSE_DEV) exec frappe bash -lc "cd /workspace/frappe-bench && bench --site $(SITE) clear-cache"

# --------------------------- PRODUCTION -----------------------------
build-prod: ## Build the custom production image via frappe_docker
	./scripts/build-prod.sh

prod-up: ## Deploy the production stack
	$(COMPOSE_PROD) up -d

prod-down: ## Stop the production stack
	$(COMPOSE_PROD) down

prod-restart: prod-down prod-up ## Restart the production stack

prod-new-site: ## Create the prod site: make prod-new-site SITE=erp.example.com (edit passwords in prod/.env first)
	$(COMPOSE_PROD) exec backend bench new-site --no-mariadb-socket $(SITE) \
		--db-root-password "$${DB_PASSWORD}" --admin-password "$${ADMIN_PASSWORD}"
	$(COMPOSE_PROD) exec backend bench --site $(SITE) install-app erpnext
	$(COMPOSE_PROD) exec backend bench --site $(SITE) install-app custom_app

prod-migrate: ## Run migrations on the production site
	$(COMPOSE_PROD) exec backend bench --site $(SITE) migrate

# ----------------------------- UPSTREAM -----------------------------
update-upstream: ## Pull latest official frappe/erpnext into the submodules
	./scripts/update-upstream.sh

push: ## Push the meta-repo (and submodules on demand)
	git push --recurse-submodules=on-demand
