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

## Setup on a new machine

Run this once on any fresh workstation before running dev/prod. The submodules
(`apps/frappe`, `apps/erpnext`) currently point at the forks
`namtran067/frappe` and `namtran067/erpnext` (branch `version-16`). Pick the scenario
below that matches your situation.

### 0. Host prerequisites

- **Git** ≥ 2.25, **GNU `make`**.
- **Docker engine** running + standalone **`docker-compose`** (the `docker compose`
  v2 plugin is broken on macOS Docker.app; the Makefile already uses the hyphenated
  form).

```bash
git --version && docker-compose version && make --version
```

---

### Scenario A — Default (clone this repo + forks, everything public)

Use this if the forks are public and you want the standard layout.

```bash
git clone --recurse-submodules https://github.com/namtran067/erp-platform.git
cd erp-platform

# if you forgot --recurse-submodules:
git submodule update --init --recursive
```

Verify:

```bash
git submodule status      # shows pinned SHA + (v16.x.x) tag
ls apps/frappe apps/erpnext apps/custom_app    # should be non-empty
```

Continue at **[Dev quick start](#dev-quick-start)** or **[Production](#production)**.

---

### Scenario B — Use the official `frappe/frappe` + `frappe/erpnext` instead of forks

Use this if you don't maintain forks (or a teammate wants the vanilla upstream).
**You only do this on the new machine — do not commit `.git/config` changes.**

```bash
# 1. Clone the meta-repo WITHOUT submodules
git clone https://github.com/namtran067/erp-platform.git
cd erp-platform

# 2. Point submodules at the official repos (local override only)
git config submodule.apps/frappe.url  https://github.com/frappe/frappe.git
git config submodule.apps/erpnext.url https://github.com/frappe/erpnext.git

# 3. Fetch + checkout the pinned SHAs from upstream
git submodule update --init --recursive
```

Notes:
- The pinned SHA in this repo exists on the official `version-16` branch, so the
  checkout succeeds.
- If you later want this to be **permanent for everyone**, edit `.gitmodules` and
  commit (but then `make update-upstream` and `prod/apps.json` should also switch to
  `frappe/...` — see [Updating upstream](#updating-upstream-frappe--erpnext)).
- **CI runners** can do the same override via a one-liner:
  ```bash
  git -c submodule.apps/frappe.url=https://github.com/frappe/frappe.git \
      -c submodule.apps/erpnext.url=https://github.com/frappe/erpnext.git \
      submodule update --init --recursive
  ```

---

### Scenario C — You already have `frappe` and `erpnext` checked out locally

Use this on a workstation where you already develop on frappe/erpnext and don't want a
second copy downloaded. We clone the meta-repo, then **replace the submodule working
trees with your existing checkouts** (kept in sync by a relative path).

```bash
# 1. Clone meta-repo WITHOUT touching submodules
git clone --no-checkout https://github.com/namtran067/erp-platform.git
cd erp-platform
git checkout main

# 2. Deinit the submodules so Git won't manage those paths
git submodule deinit -f apps/frappe apps/erpnext
git rm -rf --cached apps/frappe apps/erpnext   # untracks, keeps .gitmodules

# 3. Symlink your existing checkouts into apps/
#    (adjust paths to wherever your copies live)
ln -s ~/code/frappe     apps/frappe
ln -s ~/code/erpnext    apps/erpnext

# 4. Check them out on version-16 so they match the pinned upstream
(cd apps/frappe  && git fetch origin && git checkout version-16 && git pull)
(cd apps/erpnext && git fetch origin && git checkout version-16 && git pull)
```

> **Do not commit** the `apps/frappe` / `apps/erpnext` symlinks — leave them as local
> overrides. If you want this layout permanently, the cleaner approach is to rewrite the
> submodule URLs to `file://` paths (per-machine, never committed):
>
> ```bash
> git config submodule.apps/frappe.url  /Users/you/code/frappe
> git config submodule.apps/erpnext.url /Users/you/code/erpnext
> git submodule update --init --recursive
> ```

---

### Common steps after any scenario

**Prepare prod env** (dev needs none — its config is hard-coded in
`dev/docker-compose.yml` + `dev/init.sh`):

```bash
cp prod/.env.example prod/.env
$EDITOR prod/.env     # set SITE / DB_PASSWORD / ADMIN_PASSWORD before first deploy
```

Then continue:
- Local dev → **[Dev quick start](#dev-quick-start)**.
- Server deploy → **[Production](#production)**.

> **Gotcha:** whenever a teammate bumps a submodule and you `git pull` the meta-repo,
> re-run `git submodule update --init --recursive` so your working copy matches the new
> pinned SHA. Stale submodules cause confusing "file not found" / migration errors.

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
