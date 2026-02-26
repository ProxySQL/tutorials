#!/usr/bin/env bash
set -euo pipefail
[[ -n "${TRACE:-}" ]] && set -x


DBS=${DBS:-primary replica1 replica2}

usage() {
    echo "Usage: $0 {hosts-per-db|xxx}"
    exit 1
}

hosts-per-db() {

  for DB in ${DBS}; do
    echo ""
    echo "##### For DB '${DB}' #####"
    echo ""
    docker exec -it ${DB} psql -U ${DB_USER} -d ${DB_NAME} -c "SELECT client_addr, COUNT(*) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND client_addr IS NOT NULL GROUP BY client_addr ORDER BY 2 DESC"
  done
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
  fi

  case "$1" in
    hosts-per-db)
        hosts-per-db
        ;;
    stop)
        do_stop
        ;;
    status)
        do_status
        ;;
    restart)
        do_restart
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac
}

main $*
