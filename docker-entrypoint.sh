#!/usr/bin/env bash
set -euo pipefail

readonly authorized_keys=/home/agent/.ssh/authorized_keys
readonly host_key_dir=/var/lib/ssh-host-keys
readonly session_environment=/run/agent-environment

runuser -u agent -- env HOME=/home/agent git config --global user.name "${GIT_USER_NAME:-lingmine[bot]}"
runuser -u agent -- env HOME=/home/agent git config --global user.email "${GIT_USER_EMAIL:-188585048+sigmalko@users.noreply.github.com}"

if [[ ! -f "${authorized_keys}" || ! -s "${authorized_keys}" ]]; then
    echo "SSH public keys are missing. Mount a non-empty authorized_keys file at ${authorized_keys}." >&2
    exit 1
fi

mkdir -p /run/sshd "${host_key_dir}" /run/lock
install -o agent -g agent -m 0600 "${authorized_keys}" /run/ssh-authorized-keys
{
    printf 'export PATH=%q\n' '/home/agent/.npm-global/bin:/usr/local/bin:/usr/bin:/bin'
    printf 'export NPM_CONFIG_PREFIX=%q\n' '/home/agent/.npm-global'
    printf 'export GH_TOKEN=%q\n' "${GH_TOKEN:-}"
    printf 'export GHCR_TOKEN=%q\n' "${GHCR_TOKEN:-}"
    printf 'export GHCR_USERNAME=%q\n' "${GHCR_USERNAME:-sigmalko}"
    printf 'export AGENT_REPOSITORY=%q\n' "${AGENT_REPOSITORY:-sigmalko/Cracow}"
} >"${session_environment}"
chmod 0644 "${session_environment}"
chmod 0700 "${host_key_dir}"
if [[ ! -s "${host_key_dir}/ssh_host_ed25519_key" ]]; then
    ssh-keygen -q -t ed25519 -N '' -f "${host_key_dir}/ssh_host_ed25519_key"
fi
chmod 0600 "${host_key_dir}/ssh_host_ed25519_key"
chmod 0644 "${host_key_dir}/ssh_host_ed25519_key.pub"
chown root:root "${host_key_dir}/ssh_host_ed25519_key" "${host_key_dir}/ssh_host_ed25519_key.pub"

sshd -t
cron
exec /usr/sbin/sshd -D -e
