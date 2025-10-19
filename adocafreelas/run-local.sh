#!/usr/bin/env bash
# run-local.sh — automatiza instalação, migração, seed e inicialização (backend, worker, frontend)
# Uso: ./run-local.sh
# Requisitos: Node 20+, npm, Docker (opcional), PostgreSQL e Redis (local ou via docker-compose).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${ROOT_DIR}/logs"
BACKEND_DIR="${ROOT_DIR}/apps/backend"
FRONTEND_DIR="${ROOT_DIR}/apps/frontend"
PRISMA_SCHEMA="${ROOT_DIR}/prisma/schema.prisma"

# Helpers
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Prechecks
if [ ! -f "${ROOT_DIR}/.env" ]; then
  warn ".env not found in repo root. Creating from .env.example if available..."
  if [ -f "${ROOT_DIR}/.env.example" ]; then
    cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
    warn "Copied .env.example -> .env. Edit .env before proceeding."
  else
    err "No .env or .env.example found. Create a .env file (see .env.example). Exiting."
    exit 1
  fi
fi

if ! command -v node >/dev/null 2>&1; then
  err "node not found in PATH. Install Node 20+ and retry."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  err "npm not found in PATH. Install npm and retry."
  exit 1
fi

mkdir -p "${LOG_DIR}"

# 1) Backend: install deps, prisma generate, migrate, seed, build
info "Installing backend dependencies..."
cd "${BACKEND_DIR}"
npm ci

info "Generating Prisma client..."
npx prisma generate --schema="${PRISMA_SCHEMA}"

info "Applying Prisma migrations (interactive dev). If this is first run, follow prompts."
npx prisma migrate dev --name init --schema="${PRISMA_SCHEMA}"

if [ -f "${BACKEND_DIR}/package.json" ] && npm run | grep -q seed; then
  info "Running seed script..."
  npm run seed || warn "Seed script failed or returned non-zero. Continue anyway."
else
  warn "No seed script found in backend package.json or 'seed' script not defined."
fi

info "Building backend..."
npm run build

# 2) Start backend (background) and record PID
BACKEND_LOG="${LOG_DIR}/backend.log"
info "Starting backend (node dist/main.js) -> ${BACKEND_LOG}"
nohup node dist/main.js > "${BACKEND_LOG}" 2>&1 &
BACKEND_PID=$!
echo "${BACKEND_PID}" > "${LOG_DIR}/backend.pid"
info "Backend PID: ${BACKEND_PID}"

# 3) Start worker (background) — prefs: dev:worker uses ts-node, for production use start:worker after build
WORKER_LOG="${LOG_DIR}/worker.log"
if npm run | grep -q "dev:worker"; then
  info "Starting worker (dev:worker using ts-node) -> ${WORKER_LOG}"
  # start worker with ts-node in background (requires ts-node installed devDependency)
  nohup npm run dev:worker > "${WORKER_LOG}" 2>&1 &
  WORKER_PID=$!
else
  # try start:worker (built JS)
  info "Starting worker (start:worker using built JS) -> ${WORKER_LOG}"
  nohup npm run start:worker > "${WORKER_LOG}" 2>&1 &
  WORKER_PID=$!
fi
echo "${WORKER_PID}" > "${LOG_DIR}/worker.pid"
info "Worker PID: ${WORKER_PID}"

# 4) Frontend: install deps and start (background)
info "Installing frontend dependencies..."
cd "${FRONTEND_DIR}"
npm ci

FRONTEND_LOG="${LOG_DIR}/frontend.log"
info "Starting frontend (next dev) -> ${FRONTEND_LOG}"
# Start Next dev in background (for development). If you want production, run build + next start instead.
nohup npm run dev > "${FRONTEND_LOG}" 2>&1 &
FRONTEND_PID=$!
echo "${FRONTEND_PID}" > "${LOG_DIR}/frontend.pid"
info "Frontend PID: ${FRONTEND_PID}"

# 5) Summary and quick checks
info "All services launched. Summary:"
echo "  Backend:  http://localhost:4000  (logs: ${BACKEND_LOG}, pid: ${BACKEND_PID})"
echo "  Swagger:  http://localhost:4000/api/docs"
echo "  Frontend: http://localhost:3000  (logs: ${FRONTEND_LOG}, pid: ${FRONTEND_PID})"
echo "  Worker:   (logs: ${WORKER_LOG}, pid: ${WORKER_PID})"
echo ""
info "To stop services, run:"
echo "  kill \$(cat ${LOG_DIR}/backend.pid) || true"
echo "  kill \$(cat ${LOG_DIR}/worker.pid) || true"
echo "  kill \$(cat ${LOG_DIR}/frontend.pid) || true"
echo ""
info "Log files:"
ls -l "${LOG_DIR}" || true

info "If you prefer to run in foreground for logs, open three terminals and run:"
echo "  (1) cd ${BACKEND_DIR} && npm run dev"
echo "  (2) cd ${BACKEND_DIR} && npm run dev:worker"
echo "  (3) cd ${FRONTEND_DIR} && npm run dev"

info "Script finished."