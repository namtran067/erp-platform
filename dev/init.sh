#!/usr/bin/env bash
# ============================================================================
# Dev setup script: tạo bench + site đầu tiên dùng apps từ submodules của bạn.
# Chạy BÊN TRONG frappe container:
#   docker compose -f dev/docker-compose.yml exec frappe bash /workspace/dev/init.sh
# ============================================================================
set -e

BENCH_NAME="frappe-bench"
SITE_NAME="development.localhost"
DB_ROOT_PASSWORD="123"
ADMIN_PASSWORD="admin"

cd /workspace

# ----------------------------------------------------------------------------
# 1. Tạo bench (chỉ lần đầu). Dùng frappe từ submodule của bạn (apps/frappe).
#    bench sẽ symlink apps/frappe => edit live được.
# ----------------------------------------------------------------------------
if [ ! -d "$BENCH_NAME" ]; then
  echo "==> [1/5] Creating bench with local frappe (apps/frappe)..."
  bench init \
    --skip-redis-config-generation \
    --frappe-path /workspace/apps/frappe \
    "$BENCH_NAME"
else
  echo "==> [1/5] Bench already exists, skipping init."
fi

cd "$BENCH_NAME"

# ----------------------------------------------------------------------------
# 2. Cấu hình db + redis (chạy trong container riêng, không phải localhost).
# ----------------------------------------------------------------------------
echo "==> [2/5] Configuring db_host and redis..."
bench set-config -g db_host mariadb
bench set-config -g redis_cache "redis://redis-cache:6379"
bench set-config -g redis_queue "redis://redis-queue:6379"
bench set-config -g redis_socketio "redis://redis-queue:6379"
bench set-config -gp developer_mode 1

# Xóa các dòng redis khỏi Procfile (đã chạy trong container riêng)
sed -i '/redis/d' Procfile 2>/dev/null || true

# ----------------------------------------------------------------------------
# 3. Install erpnext từ submodule (apps/erpnext) - editable install => live.
# ----------------------------------------------------------------------------
if [ ! -e "apps/erpnext" ]; then
  echo "==> [3/5] Installing erpnext from local submodule (apps/erpnext)..."
  bench get-app /workspace/apps/erpnext
else
  echo "==> [3/5] erpnext already linked, skipping."
fi

# ----------------------------------------------------------------------------
# 4. Tạo site đầu tiên + install erpnext.
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
echo "Bây giờ khởi động dev server (chạy trong terminal riêng, sẽ block để xem logs):"
echo ""
echo "    cd /workspace/frappe-bench && bench start"
echo ""
echo "Sau đó truy cập:  http://$SITE_NAME:8000"
echo "Login: Administrator / $ADMIN_PASSWORD"
echo ""
echo "(Trên macOS, *.localhost tự resolve về 127.0.0.1, không cần sửa /etc/hosts)"
