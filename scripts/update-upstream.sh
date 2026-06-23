#!/usr/bin/env bash
# ============================================================================
# Pull the latest commits from the OFFICIAL upstream (frappe/frappe,
# frappe/erpnext) into your fork branches and record the new SHAs in the
# meta-repo. Your submodules point at your forks (namtran067/...), so we fetch
# from official upstream and fast-forward your version-16 branch, then you push
# the fork and commit the new SHA here.
#
# Run from the repo root:  ./scripts/update-upstream.sh   (or: make update-upstream)
# ============================================================================
set -euo pipefail

update_app () {
  local path="$1" upstream="$2"
  echo "==> ${path}: fetching from official upstream (${upstream}) ..."
  # Add an 'upstream' remote inside the submodule if it's not there yet.
  git -C "$path" remote get-url upstream >/dev/null 2>&1 \
    || git -C "$path" remote add upstream "$upstream"
  git -C "$path" fetch upstream
  # Switch the submodule from detached HEAD onto its working branch, then fast-forward.
  git -C "$path" checkout version-16
  git -C "$path" merge --ff-only upstream/version-16
  echo "    ${path} now at $(git -C "$path" rev-parse --short HEAD)"
}

update_app apps/frappe  https://github.com/frappe/frappe.git
update_app apps/erpnext https://github.com/frappe/erpnext.git

cat <<EOF

==> Upstream merged into your fork branches. Next steps:

  1. Push the forks:
       (cd apps/frappe  && git push origin version-16)
       (cd apps/erpnext && git push origin version-16)

  2. Record the new SHAs in the meta-repo:
       git add apps/frappe apps/erpnext
       git commit -m "chore: update upstream frappe/erpnext"

  3. Rebuild and redeploy production:
       make build-prod && make prod-up && make prod-migrate SITE=your.site

  4. Test thoroughly — upstream changes may conflict with your custom_app
     overrides (hooks / DocTypes). Fix any breakage in apps/custom_app.
EOF
