## Quick install

Run these commands on the VPS that will host the container. Docker Engine and the Docker Compose v2 plugin must be installed on the VPS.

```bash
mkdir -p ~/agents-in-docker/.ssh
cd ~/agents-in-docker
curl -fsSLO https://github.com/sigmalko/agents-in-docker/releases/latest/download/docker-compose.yml
curl -fsSL https://github.com/sigmalko/agents-in-docker/releases/latest/download/env.example -o .env.example
cp .env.example .env
```

## Configure access

Edit `~/agents-in-docker/.env`. Set `GH_TOKEN` to a GitHub token that can access the repository to clone. `AGENT_REPOSITORY` defaults to `sigmalko/Cracow`; change it to another `OWNER/REPOSITORY` if needed. The Git author defaults to `lingmine[bot] <188585048+sigmalko@users.noreply.github.com>` and can be changed with `GIT_USER_NAME` and `GIT_USER_EMAIL`. Keep `.env` private.

If GHCR requires authentication to pull the image, set `GHCR_USERNAME` and `GHCR_TOKEN` in `.env`, then run on the VPS:

```bash
cd ~/agents-in-docker
set -a && . ./.env && set +a
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io --username "$GHCR_USERNAME" --password-stdin
```

Create an SSH key on your computer and copy its public key to the VPS. Replace `VPS_USER` and `VPS_ADDRESS` with your VPS login and address:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/agents-in-docker -C agents-in-docker
scp ~/.ssh/agents-in-docker.pub VPS_USER@VPS_ADDRESS:~/agents-in-docker/.ssh/authorized_keys
ssh VPS_USER@VPS_ADDRESS 'chmod 700 ~/agents-in-docker/.ssh && chmod 600 ~/agents-in-docker/.ssh/authorized_keys'
```

## Start and connect

On the VPS, open TCP ports `2222` (SSH) and `7777` (services) in its firewall, then start the container:

```bash
cd ~/agents-in-docker
docker compose pull
docker compose up -d
```

Connect from your computer with:

```bash
ssh -i ~/.ssh/agents-in-docker -p 2222 agent@VPS_ADDRESS
```

The SSH session opens in `/workspaces`. Port `7777` is published for services started inside the container; those services must listen on `0.0.0.0:7777`.

See the [README](https://github.com/sigmalko/agents-in-docker#readme) for all settings and troubleshooting.
