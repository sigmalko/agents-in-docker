#!/usr/bin/env bash
set -uo pipefail

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

readonly agent_home=/home/agent
readonly agent_path=/home/agent/.npm-global/bin:/usr/local/bin:/usr/bin:/bin
readonly log_file=/var/log/agent-cli-updates.log
readonly max_log_lines=5000

log() {
    printf '[agent-cli-update] %s %s\n' "$(date --iso-8601=seconds)" "$*"
}

version_of() {
    timeout 60 runuser -u agent -- env HOME="${agent_home}" \
        NPM_CONFIG_PREFIX=/home/agent/.npm-global PATH="${agent_path}" "$@" 2>&1 | head -n 1 || true
}

trim_log() {
    local lines tmp
    [[ -f "${log_file}" ]] || return 0
    lines="$(wc -l <"${log_file}" 2>/dev/null || echo 0)"
    [[ "${lines}" -gt "${max_log_lines}" ]] || return 0
    tmp="$(mktemp /var/log/.agent-cli-updates.XXXXXX)" || return 0
    if tail -n "${max_log_lines}" "${log_file}" >"${tmp}"; then
        cat "${tmp}" >"${log_file}"
    fi
    rm -f "${tmp}"
}

exec 9>/run/lock/agent-cli-update.lock
if ! flock -n 9; then
    log "Update skipped because another run holds the lock"
    exit 0
fi

log "Starting scheduled Codex and Claude Code updates"
log "Versions before: codex=$(version_of codex --version); claude=$(version_of claude --version)"
if timeout 15m runuser -u agent -- env HOME="${agent_home}" \
    NPM_CONFIG_PREFIX=/home/agent/.npm-global PATH="${agent_path}" \
    npm install --global --allow-scripts=@anthropic-ai/claude-code \
        @openai/codex@latest @anthropic-ai/claude-code@latest; then
    update_rc=0
else
    update_rc=$?
fi
log "Versions after: codex=$(version_of codex --version); claude=$(version_of claude --version); rc=${update_rc}"
log "Scheduled update finished"
trim_log
exit "${update_rc}"
