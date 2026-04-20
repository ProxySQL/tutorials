#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON="$SCRIPT_DIR/../common"
BASE="$SCRIPT_DIR/data"

"$COMMON/proxysql_sandbox.sh" destroy "$BASE/proxysql"   || true
"$COMMON/pg_sandbox.sh"       destroy "$BASE/replica-2"  || true
"$COMMON/pg_sandbox.sh"       destroy "$BASE/replica-1"  || true
"$COMMON/pg_sandbox.sh"       destroy "$BASE/primary"    || true
rm -rf "$BASE"
echo "tear-down complete."
