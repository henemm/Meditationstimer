#!/usr/bin/env bash
# Übernommen aus loose-ends server/scripts/test-local.sh @ 24a6da6; angepasst: Postgres-Pfad (pg_config, Linux, Homebrew), Start als root über Nutzer postgres
# Typecheck and tests against a throwaway Postgres (own data folder, free port, TCP only), always cleaned up.
set -euo pipefail

# Postgres binaries: pg_config first, then the highest /usr/lib/postgresql/*/bin, then Homebrew.
if command -v pg_config >/dev/null 2>&1 && [ -x "$(pg_config --bindir)/initdb" ]; then
  pg_bin="$(pg_config --bindir)"
else
  pg_bin="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)"
  [ -n "$pg_bin" ] || pg_bin="/opt/homebrew/opt/postgresql@18/bin"
fi
export PATH="$pg_bin:$PATH"
server_dir="$(cd "$(dirname "$0")/.." && pwd)"
data_dir="$(mktemp -d)"
port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"

# Postgres refuses to run as root: hand the data folder to "postgres" when needed.
run_pg() { if [ "$(id -u)" = 0 ]; then chown postgres "$data_dir" && su postgres -s /bin/bash -c "PATH='$PATH'; $*"; else bash -c "$*"; fi; }

cleanup() {
  run_pg "pg_ctl -D '$data_dir/pg' -m fast stop" >/dev/null 2>&1 || true
  rm -rf "$data_dir"
}
trap cleanup EXIT

run_pg "initdb -D '$data_dir/pg' -U postgres -A trust >'$data_dir/initdb.log'"
# No Unix socket: a temp path is too long for one (103 bytes at most).
run_pg "pg_ctl -D '$data_dir/pg' -l '$data_dir/postgres.log' -o '-p $port -c unix_socket_directories= -c listen_addresses=127.0.0.1' -w start >/dev/null"
echo "Postgres on 127.0.0.1:$port, data in $data_dir"

export DATABASE_URL="postgres://postgres@127.0.0.1:$port/postgres"
cd "$server_dir"
[ -d node_modules ] || npm ci
npm run typecheck
npm test
