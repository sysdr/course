#!/bin/bash
# Generate API traffic so dashboard audit metrics reflect demo activity.
set -e
BASE="http://127.0.0.1:8000"
resp=$(curl -sf -X POST "${BASE}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}') || exit 0
token=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" <<< "$resp")
[[ -z "$token" ]] && exit 0
curl -sf -H "Authorization: Bearer ${token}" "${BASE}/api/logs/search?limit=10" >/dev/null || true
curl -sf -H "Authorization: Bearer ${token}" "${BASE}/api/admin/audit-summary" >/dev/null || true
echo "Demo API calls completed."
