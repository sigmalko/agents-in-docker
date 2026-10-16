# agents-in-docker

A Docker Compose environment for running coding agents over SSH. The published image includes the current Node.js release, OpenAI Codex CLI, Claude Code, Git, GitHub CLI (`gh`), GitLab CLI (`glab`), `jq`, `curl`, `tmux`, `sshd`, and cron. It does not install Python or Docker.

GitHub Actions builds the image and publishes it to `ghcr.io/sigmalko/agents-in-docker`. The Compose setup pulls that image; it does not build locally.

## Requirements

- Docker Engine and the Docker Compose v2 plugin on the VPS;
- a firewall or cloud security group that allows inbound TCP ports `2222` and `7777`;
- an SSH key pair on the client computer.

Docker must be installed on the VPS host. It is not installed inside the agent container.

## Start from GHCR

Create a directory on the VPS and put these two files in it: `docker-compose.yml` from this repository and a local `.env` based on `.env.example`.

```bash
mkdir -p ~/agents-in-docker/.ssh
cd ~/agents-in-docker
curl -fsSLO https://raw.githubusercontent.com/sigmalko/agents-in-docker/main/docker-compose.yml
curl -fsSLO https://raw.githubusercontent.com/sigmalko/agents-in-docker/main/.env.example
cp .env.example .env
```

Create an SSH key for this container if you do not already have one. Keep the private key on your client computer; only copy its `.pub` file to the VPS.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/agents-in-docker -C agents-in-docker
install -m 600 ~/.ssh/agents-in-docker.pub ~/agents-in-docker/.ssh/authorized_keys
```

If you already have an SSH public key, copy that public key into `~/agents-in-docker/.ssh/authorized_keys` instead. Confirm that `.env` contains the correct path in `SSH_AUTHORIZED_KEYS`. The default is `./.ssh/authorized_keys`.

Edit `.env` and set `GH_TOKEN` to a GitHub token that can access the repositories you want the agents to use. `AGENT_REPOSITORY` defaults to `sigmalko/Cracow` and can be changed to another `OWNER/REPOSITORY`. `GHCR_TOKEN` and `GHCR_USERNAME` are for authenticating the VPS host to GHCR when the image is private; `GHCR_TOKEN` needs `read:packages` access. The `.env` file is ignored by Git and is mounted into the container as environment variables by Compose.

For a private GHCR image, log in on the VPS before pulling:

```bash
set -a
. ./.env
set +a
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io --username "$GHCR_USERNAME" --password-stdin
```

Start the container:

```bash
docker compose pull
docker compose up -d
docker compose ps
```

On the first build, GitHub Actions publishes the package. If GHCR does not allow anonymous pulls, open the package settings under GitHub **Packages** and set the package visibility to **Public**, or authenticate on the VPS with `docker login ghcr.io` using a token with `read:packages` access.

## Connect over SSH

From the client computer, connect to the VPS public IP or DNS name:

```bash
ssh -i ~/.ssh/agents-in-docker -p 2222 agent@VPS_ADDRESS
```

The container accepts public-key authentication only. Password authentication and root login are disabled. On the first connection, verify the SSH host-key fingerprint shown by the client. The host key persists in a Docker named volume across container restarts and recreation.

The container listens on SSH port `22`; Compose publishes it as host port `2222` by default. Change `SSH_PORT` in `.env` to use a different host port, and open that port in the VPS firewall.

## Port 7777

Compose publishes container port `7777` on host port `7777` on all host interfaces. Open TCP `7777` in the VPS firewall or cloud security group to allow internet connections. The image leaves this port available for an agent-managed service. A service must listen on `0.0.0.0:7777` inside the container; binding to `127.0.0.1` will make it unreachable from outside.

For example, start a small Node.js HTTP service in an SSH session:

```bash
node -e 'require("node:http").createServer((req, res) => { res.end("agents-in-docker is up\\n"); }).listen(7777, "0.0.0.0")'
```

Then visit `http://VPS_ADDRESS:7777` or test with `curl http://VPS_ADDRESS:7777`. Set `SERVICE_PORT` in `.env` to change the host-side port; the container service still listens on `7777`.

## Clone the configured repository

Compose passes `GH_TOKEN` and `AGENT_REPOSITORY` into the container. `gh` uses `GH_TOKEN` automatically for GitHub authentication. After connecting over SSH, clone the configured repository into the persistent workspace with:

```bash
gh repo clone "$AGENT_REPOSITORY" "/workspace/${AGENT_REPOSITORY##*/}"
```

`GHCR_TOKEN` is also available in the container for scripts that need it. The container has no Docker client or Docker daemon.

## Configuration

`.env.example` documents the supported Compose settings:

```dotenv
COMPOSE_PROJECT_NAME=agents-in-docker
IMAGE=ghcr.io/sigmalko/agents-in-docker:latest
SSH_PORT=2222
SERVICE_PORT=7777
SSH_AUTHORIZED_KEYS=./.ssh/authorized_keys
TZ=Europe/Warsaw
GH_TOKEN=replace_with_github_token
GHCR_TOKEN=replace_with_ghcr_token
GHCR_USERNAME=sigmalko
AGENT_REPOSITORY=sigmalko/Cracow
```

The Compose service uses named volumes for `/workspace` and the Codex and Claude Code configuration directories, so work files and CLI authentication survive container replacement. Connect over SSH and use `/workspace` for agent work. To mount a host directory instead, replace the `agent-workspace:/workspace` entry in Compose with an absolute host path such as `/srv/agent-workspace:/workspace`.

## CLI updates and cron

The system cron job updates Codex and Claude Code every day at `04:00` in the container timezone (`Europe/Warsaw` by default). It runs both npm updates as the unprivileged `agent` user and records output in `/var/log/agent-cli-updates.log`.

```bash
docker compose exec agent tail -n 100 /var/log/agent-cli-updates.log
docker compose exec agent codex --version
docker compose exec agent claude --version
```

The CLIs are installed at the latest version available when the image is built, then refreshed by cron. Authenticate each CLI from the SSH session using its normal interactive login flow. Their configuration and authentication data persist in named volumes.

## Image tags and publishing

GitHub Actions builds on pull requests without publishing. Pushes to `main` publish `latest`, a numbered tag, and a commit SHA tag to GHCR. You can select another published tag by changing `IMAGE` in `.env`.

To refresh the running container after a new image is published:

```bash
docker compose pull
docker compose up -d
```

The Compose file only pulls the published image. To build and test locally, run `docker build -t agents-in-docker .` from the repository root.
