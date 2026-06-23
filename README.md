# ERP Platform — Frappe + ERPNext (v16) with a Custom App

A **meta-repo** that orchestrates [Frappe](https://github.com/frappe/frappe) +
[ERPNext](https://github.com/frappe/erpnext) via git **submodules**, and keeps all
your customizations in a separate app so updating upstream never overwrites your work.

- **Dev** — Docker-based; the host stays clean (no host Python/Node version headaches).
- **Prod** — single-host `docker-compose` + a custom image built the official way.
- **Customize** — via your own app (`apps/custom_app`) using hooks/overrides. **Never**
  edit `apps/frappe` or `apps/erpnext` directly.

---

## Repo layout

```
erp-platform/
├── apps/
│   ├── frappe/          # submodule → your fork (version-16)
│   ├── erpnext/         # submodule → your fork (version-16)
│   └── custom_app/      # submodule → YOUR app (overrides, DocTypes, fixtures, ...)
├── dev/                 # dev stack (docker-compose.yml, init.sh, new-custom-app.sh)
├── frappe-bench/        # generated bench dir (gitignored), apps symlink to submodules
├── prod/                # production stack
│   ├── docker-compose.yml
│   ├── apps.json        # extra apps baked into the image (erpnext + custom_app)
│   ├── .env.example
│   └── frappe_docker/   # cloned on demand by build-prod.sh (gitignored)
├── scripts/
│   ├── build-prod.sh
│   └── update-upstream.sh
├── Makefile
├── AGENTS.md
└── .gitmodules
```

---

## Prerequisites

- **Docker engine** running.
- **`docker-compose`** (standalone, hyphenated). On this host the `docker compose`
  v2 plugin is broken (dangling Docker.app symlinks), so **every command uses
  `docker-compose`** (the Makefile and scripts already do).

```bash
docker-compose version    # should print a version
```

---

## Dev quick start

```bash
# 1. Clone with submodules (first time)
git clone --recurse-submodules <this-repo> erp-platform
cd erp-platform
git submodule update --init --recursive

# 2. Start dev containers (mariadb, redis, frappe)
make dev-up

# 3. Create the bench + first site + install erpnext (idempotent — safe to re-run)
make dev-init

# 4. Run the dev server (blocks the terminal, shows logs)
make dev-start
```

Open <http://development.localhost:8000> → log in with `Administrator / admin`.
On macOS, `*.localhost` resolves to `127.0.0.1` automatically.

### Common dev commands

| Command | Description |
|---|---|
| `make dev-up` / `dev-down` / `dev-restart` | Manage dev containers |
| `make dev-init` | Create bench + site + install erpnext (idempotent) |
| `make dev-start` | Run `bench start` (blocks) |
| `make dev-shell` | Shell into the frappe container |
| `make dev-migrate SITE=development.localhost` | Run migrations |
| `make dev-clear-cache SITE=development.localhost` | Clear cache |
| `make new-app APP_NAME=my_app` | Scaffold a new custom app |
| `make dev-build-app APP_NAME=custom_app` | Rebuild one app's assets |
| `make dev-build-assets` | Rebuild ALL apps' assets |

---

## Creating & editing your custom app

Customizations live in `apps/custom_app/` (version controlled in the meta-repo). The
`new-custom-app.sh` script scaffolds the app there and symlinks it into the bench, so
source edits take effect immediately.

```bash
# Create the app (interactive; press Enter for defaults)
make new-app APP_NAME=custom_app
```

Then edit files under `apps/custom_app/`:

- **JS/CSS/HTML changes** → `make dev-build-app APP_NAME=custom_app` (or `bench build`).
- **Python changes** → restart the server (`Ctrl+C` in the `make dev-start` terminal,
  then `make dev-start` again).
- **DocType / schema changes** → `make dev-migrate`.

> **Rule of thumb:** never edit `apps/frappe` or `apps/erpnext`. Put overrides, custom
> fields, fixtures, print formats, and JS/Python overrides in `apps/custom_app` (via
> `hooks.py`). That way pulling upstream can never clobber your changes.

### Publish the custom app as a submodule (one-time)

After `make new-app`, the app exists locally under `apps/custom_app`. Push it to its
own repo and register it as a submodule:

```bash
cd apps/custom_app
git init && git add -A && git commit -m "init: custom_app"
git remote add origin git@github.com:namtran067/custom_app.git
git branch -M main && git push -u origin main
cd ../..
git submodule add -b main git@github.com:namtran067/custom_app.git apps/custom_app
```

---

## Production

```bash
# 1. Configure env
cp prod/.env.example prod/.env
#   edit prod/.env: site name, DB_PASSWORD, ADMIN_PASSWORD, ...

# 2. Build the custom image (clones frappe_docker on demand, uses prod/apps.json)
make build-prod

# 3. Deploy
make prod-up

# 4. Create the production site (first time only)
make prod-new-site SITE=erp.example.com

# 5. Migrate after any app upgrade
make prod-migrate SITE=erp.example.com
```

The image build is the **official** frappe_docker flow: `scripts/build-prod.sh` clones
`frappe_docker` into `prod/frappe_docker/` (gitignored) and builds
`images/custom/Containerfile` with `prod/apps.json` as a build secret. `prod/apps.json`
lists only the **extra** apps (erpnext + custom_app) — frappe itself comes from the
`FRAPPE_PATH`/`FRAPPE_BRANCH` build args (see `scripts/build-prod.sh`).

The frontend (nginx) is published on **host port 80** → put a TLS-terminating proxy
(Traefik / nginx + certbot) in front for HTTPS (out of scope here).

---

## Updating upstream (Frappe / ERPNext)

```bash
make update-upstream
```

`scripts/update-upstream.sh` fetches the **official** `frappe/frappe` and
`frappe/erpnext` and fast-forwards your fork's `version-16` branch. Then:

1. Push the forks:
   ```bash
   (cd apps/frappe  && git push origin version-16)
   (cd apps/erpnext && git push origin version-16)
   ```
2. Record the new SHAs in the meta-repo:
   ```bash
   git add apps/frappe apps/erpnext
   git commit -m "chore: update upstream frappe/erpnext"
   ```
3. Rebuild and redeploy:
   ```bash
   make build-prod && make prod-up && make prod-migrate SITE=erp.example.com
   ```
4. **Test thoroughly** — upstream changes may conflict with your `custom_app` overrides.

---

## Troubleshooting

- **`docker compose ...` fails with "not a docker command"** → use `docker-compose`
  (hyphen). The v2 plugin symlinks are broken on this host; the standalone Homebrew
  binary works.
- **`bench init` complains about Python version** → dev uses Python 3.14.2 (pinned in
  `dev/init.sh`); frappe v16.23+ requires Python ≥ 3.14. The `frappe/bench:latest`
  image ships it via pyenv.
- **`git` "dubious ownership" warnings in the container** → already handled by
  `git config --global --add safe.directory '*'` in `init.sh` / `new-custom-app.sh`.
- **Edits in `apps/custom_app` not showing** → rebuild assets
  (`make dev-build-app APP_NAME=custom_app`) and/or restart the server.
- **Site not reachable** → run `make dev-init` again (idempotent) and check
  `make dev-start` logs.

---

## Next steps (out of scope for now)

- TLS/HTTPS for the production domain (Traefik + Let's Encrypt / nginx + certbot).
- Automated backups (MariaDB dumps, sites volume, off-site to S3/R2).
- Monitoring & alerting (Prometheus/Grafana, healthchecks).
- CI/CD pipeline to build/test/deploy the image automatically.
- Additional apps (HR, CRM, …) → add to `prod/apps.json` and the dev submodules.
