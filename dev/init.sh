#!/usr/bin/env bash
# ============================================================================
# Dev setup script: creates the bench + first site using apps from your submodules.
# Run INSIDE the frappe container:
#   docker-compose -f dev/docker-compose.yml exec frappe bash /workspace/dev/init.sh
# ============================================================================
set -e

BENCH_NAME="frappe-bench"
SITE_NAME="development.localhost"
DB_ROOT_PASSWORD="123"
ADMIN_PASSWORD="admin"
PY_VERSION="3.14.2"    # frappe v16.23+ requires Python>=3.14 (image ships 3.14.2)

cd /workspace

# ----------------------------------------------------------------------------
# 0. Fix git "dubious ownership" (host -> container volume mount) + pin Python.
# ----------------------------------------------------------------------------
git config --global --add safe.directory '*'
export PYENV_VERSION="$PY_VERSION"

# Remove a half-created bench if a previous init failed, so we can start clean.
if [ -d "$BENCH_NAME" ] && [ ! -f "$BENCH_NAME/sites/common_site_config.json" ]; then
  echo "==> [0/5] Removing incomplete bench (previous failed init)..."
  rm -rf "$BENCH_NAME"
fi

# ----------------------------------------------------------------------------
# 1. Create the bench (only the first time). Uses frappe from your submodule
#    (apps/frappe); bench symlinks it so you can edit it live.
# ----------------------------------------------------------------------------
if [ ! -d "$BENCH_NAME" ]; then
  echo "==> [1/5] Creating bench with local frappe (apps/frappe) [Python $PY_VERSION]..."
  bench init \
    --skip-redis-config-generation \
    --frappe-path /workspace/apps/frappe \
    --python "$PY_VERSION" \
    "$BENCH_NAME"
else
  echo "==> [1/5] Bench already exists, skipping init."
fi

cd "$BENCH_NAME"

# ----------------------------------------------------------------------------
# 2. Configure db + redis (they run in separate containers, not localhost).
# ----------------------------------------------------------------------------
echo "==> [2/5] Configuring db_host and redis..."
bench set-config -g db_host mariadb
bench set-config -g redis_cache "redis://redis-cache:6379"
bench set-config -g redis_queue "redis://redis-queue:6379"
bench set-config -g redis_socketio "redis://redis-queue:6379"
bench set-config -gp developer_mode 1

# Remove redis lines from the Procfile (those services run in their own containers)
sed -i '/redis/d' Procfile 2>/dev/null || true

# ----------------------------------------------------------------------------
# 3. Install erpnext from the submodule (apps/erpnext) - editable install => live.
# ----------------------------------------------------------------------------
if [ ! -e "apps/erpnext" ]; then
  echo "==> [3/5] Installing erpnext from local submodule (apps/erpnext)..."
  bench get-app /workspace/apps/erpnext
else
  echo "==> [3/5] erpnext already linked, skipping."
fi

# ----------------------------------------------------------------------------
# 4. Create the first site + install erpnext.
# ----------------------------------------------------------------------------
if [ ! -d "sites/$SITE_NAME" ]; then
  echo "==> [4/5] Creating site $SITE_NAME..."
  bench new-site \
    --db-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --mariadb-user-host-login-scope=% \
    "$SITE_NAME"
  bench --site "$SITE_NAME" install-app erpnext
  bench --site "$SITE_NAME" clear-cache
else
  echo "==> [4/5] Site $SITE_NAME already exists, skipping."
fi

# ----------------------------------------------------------------------------
# 5. Done.
# ----------------------------------------------------------------------------
echo ""
echo "=========================================================================="
echo "==> [5/5] DONE!"
echo "=========================================================================="
echo ""
echo "Now start the dev server (run in a separate terminal; it blocks to show logs):"
echo ""
echo "    cd /workspace/frappe-bench && bench start"
echo ""
echo "Then open:  http://$SITE_NAME:8000"
echo "Login: Administrator / $ADMIN_PASSWORD"
echo ""
echo "(On macOS, *.localhost resolves to 127.0.0.1 automatically; no /etc/hosts edit needed.)"
