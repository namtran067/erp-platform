# AGENTS.md — guidance for AI agents (Kilo / Claude / etc.)

This repo is a **meta-repo** orchestrating Frappe + ERPNext (v16) via git submodules,
with a custom app for all customizations. Read this before making changes.

## Golden rules

1. **Never edit `apps/frappe` or `apps/erpnext`** — they are read-only upstream
   submodules. All customizations go in `apps/custom_app` (hooks, DocTypes, fixtures,
   print formats, JS/Python overrides).
2. **All Docker commands use `docker-compose` (hyphen), NOT `docker compose`.** The v2
   plugin is broken on this host; the standalone Homebrew binary works. The `Makefile`
   and `scripts/*.sh` already account for this.
3. Dev runs **inside containers** (`frappe/bench:latest`). The host's Python/Node
   versions are irrelevant — don't install Python/Node on the host to "fix" things.
4. The bench dir `frappe-bench/` is generated and **gitignored**; its `apps/` are
   symlinks back to the submodules. Don't commit anything under `frappe-bench/`.

## Intent → command map

| User intent | Command |
|---|---|
| Start dev | `make dev-up` then `make dev-init` then `make dev-start` |
| Stop / restart dev | `make dev-down` / `make dev-restart` |
| Shell into dev container | `make dev-shell` |
| Create a new custom app | `make new-app APP_NAME=<name>` |
| Install an app on the site | `make dev-install-app APP_NAME=<name>` |
| Rebuild one app's assets | `make dev-build-app APP_NAME=<name>` |
| Rebuild all assets | `make dev-build-assets` |
| Run migrations | `make dev-migrate SITE=development.localhost` |
| Clear cache | `make dev-clear-cache SITE=development.localhost` |
| Build prod image | `make build-prod` |
| Deploy prod | `make prod-up` |
| Create prod site | `make prod-new-site SITE=<host>` (after editing `prod/.env`) |
| Migrate prod | `make prod-migrate SITE=<host>` |
| Update frappe/erpnext upstream | `make update-upstream` (+ follow printed steps) |

## Where things live

- **Customization source:** `apps/custom_app/` (this is where you make edits).
- **Dev stack:** `dev/` — `docker-compose.yml`, `init.sh`, `new-custom-app.sh`.
- **Prod stack:** `prod/` — `docker-compose.yml`, `apps.json`, `.env.example`.
- **Build/update logic:** `scripts/build-prod.sh`, `scripts/update-upstream.sh`.
- **Config constants (dev):** hard-coded in `dev/docker-compose.yml` and `dev/init.sh`
  (mirrored in `dev/.env.example` for reference).

## Common pitfalls

- `prod/apps.json` lists **only extra apps** (erpnext, custom_app). Frappe itself is
  installed via the `FRAPPE_PATH`/`FRAPPE_BRANCH` build args in `scripts/build-prod.sh`.
- `prod/apps.json` URLs point at the **forks** (`namtran067/...`) to match the dev
  submodules. Switch to official `frappe/...` if you stop using forks.
- `make prod-new-site` reads `DB_PASSWORD` and `ADMIN_PASSWORD` from `prod/.env` —
  change the placeholders before running it.
- After editing `apps/custom_app`, rebuild assets and/or restart the server before
  verifying on the site.
