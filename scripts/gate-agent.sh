#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 keese-ai
#
# Quiet wrapper around `make gate`: one PASS/FAIL line per stage instead of
# the full raw output, which otherwise dominates an agent's transcript. Full
# logs are teed to $KORYPH_PHASE_DIR (a dispatch's scratch dir) or
# .plan-logs/gate/ when run outside a dispatch. See AGENTS.md "Output economy".

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"
# shellcheck source=scripts/lib/log.sh
source "${REPO_ROOT}/scripts/lib/log.sh"

LOG_DIR="${KORYPH_PHASE_DIR:-${REPO_ROOT}/.plan-logs/gate}"
mkdir -p "${LOG_DIR}"

STAGES=(fmt vet lint test coverage-check bundle-validate)

gate::stage() {
  local target="$1"
  local logfile="${LOG_DIR}/gate-${target}.log"
  if ! make "${target}" >"${logfile}" 2>&1; then
    log::err "FAIL ${target} — full output: ${logfile}"
    tail -n 20 "${logfile}" >&2
    return 1
  fi
  log::ok "PASS ${target}"
}

gate::design() {
  local logfile="${LOG_DIR}/gate-design-gate.log"
  if ! bash "${REPO_ROOT}/scripts/check-design-gate.sh" >"${logfile}" 2>&1; then
    log::err "FAIL design-gate — full output: ${logfile}"
    tail -n 20 "${logfile}" >&2
    return 1
  fi
  log::ok "PASS design-gate"
}

for stage in "${STAGES[@]}"; do
  gate::stage "${stage}"
done
gate::design
log::ok "gate green"
