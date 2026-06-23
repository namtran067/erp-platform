#!/usr/bin/env bash
# ============================================================================
# Create a new custom app: keep the real source at /workspace/apps/<name>
# (meta-repo, version controlled) and symlink it into frappe-bench/apps/ so
# bench can use it.
#
# How to run (inside the container):
#   docker-compose -f dev/docker-compose.yml exec frappe bash /workspace/dev/new-custom-app.sh custom_app
# ============================================================================
set -e

APP_NAME="${1:-custom_app}"
SITE_NAME="development.localhost"
BENCH_DIR="/workspace/frappe-bench"
META_APPS_DIR="/workspace/apps"

export PYENV_VERSION="3.14.2"
git config --global --add safe.directory '*'

cd "$BENCH_DIR"

# If the app already exists in the meta-repo, just re-create the symlink.
if [ -e "$META_APPS_DIR/$APP_NAME" ]; then
  echo "==> App $APP_NAME already exists at $META_APPS_DIR/$APP_NAME, just re-symlinking..."
else
  echo "==> [1/4] Creating app $APP_NAME with bench new-app (press Enter to accept defaults)..."
  bench new-app "$APP_NAME"

  # bench creates it under frappe-bench/apps/<name> -> move it into the meta-repo
  echo "==> [2/4] Moving the app into the meta-repo ($META_APPS_DIR/$APP_NAME) and re-symlinking..."
  mv "apps/$APP_NAME" "$META_APPS_DIR/$APP_NAME"
fi

# Make sure the symlink exists inside the bench
ln -sfn "$META_APPS_DIR/$APP_NAME" "apps/$APP_NAME"

# Install (editable) into the venv
echo "==> [3/4] pip install -e (editable)..."
./env/bin/pip install -e "apps/$APP_NAME" -q

# Build assets + install into the site
echo "==> [4/4] Build assets + install into site $SITE_NAME..."
bench build --app "$APP_NAME"
bench --site "$SITE_NAME" install-app "$APP_NAME"

echo ""
echo "=========================================================================="
echo "==> DONE! App '$APP_NAME' is ready."
echo "    - Real source:   $META_APPS_DIR/$APP_NAME  (version controlled in the meta-repo)"
echo "    - Bench symlink: $BENCH_DIR/apps/$APP_NAME -> ^"
echo "    - Installed on:  $SITE_NAME"
echo "=========================================================================="
echo ""
echo "Start editing: change files under $META_APPS_DIR/$APP_NAME/"
echo "After JS/CSS changes:  bench build --app $APP_NAME"
echo "After Python changes:  restart the server (Ctrl+C, then bench start again)"
