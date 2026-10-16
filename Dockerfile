FROM node:current-trixie-slim

LABEL org.opencontainers.image.title="agents-in-docker" \
    org.opencontainers.image.description="Run OpenAI Codex and Claude Code in a persistent Docker Compose container over SSH." \
    org.opencontainers.image.url="https://github.com/sigmalko/agents-in-docker" \
    org.opencontainers.image.documentation="https://github.com/sigmalko/agents-in-docker#readme" \
    org.opencontainers.image.source="https://github.com/sigmalko/agents-in-docker" \
    org.opencontainers.image.vendor="sigmalko"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Warsaw \
    NPM_CONFIG_PREFIX=/home/agent/.npm-global \
    PATH=/home/agent/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Base utilities, SSH, cron, and the GitHub CLI repository.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        cron \
        git \
        jq \
        openssh-server \
        tmux \
        tzdata \
        util-linux \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" \
        > /etc/apt/sources.list.d/github-cli.list \
    && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && printf '%s\n' "${TZ}" > /etc/timezone \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Install the latest GitLab CLI release for the image architecture.
RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
        amd64) glab_arch=amd64 ;; \
        arm64) glab_arch=arm64 ;; \
        *) echo "Unsupported architecture for glab: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    glab_url="$(curl -fsSL 'https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest' \
        | jq -er --arg arch "${glab_arch}" '.assets.links[] | select(.name | test("_linux_" + $arch + "\\.deb$")) | .direct_asset_url' \
        | head -n 1)"; \
    curl -fsSL "${glab_url}" -o /tmp/glab.deb; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/glab.deb; \
    rm -f /tmp/glab.deb; \
    rm -rf /var/lib/apt/lists/*

RUN usermod --login agent --home /home/agent --move-home node \
    && groupmod --new-name agent node \
    && passwd --delete agent \
    && install -d -o agent -g agent -m 0700 /home/agent/.ssh /home/agent/.npm-global /workspaces \
    && install -d -m 0755 /var/lib/ssh-host-keys /run/sshd

# Install both agent CLIs as the SSH user, without requiring root at runtime.
USER agent
RUN npm install --global --allow-scripts=@anthropic-ai/claude-code \
        @openai/codex@latest @anthropic-ai/claude-code@latest \
    && codex --version \
    && claude --version
USER root

COPY sshd_config /etc/ssh/sshd_config
COPY docker-entrypoint.sh /usr/local/sbin/docker-entrypoint
COPY agent-shell.sh /usr/local/bin/agent-shell
COPY scripts/update-agent-clis.sh /usr/local/sbin/update-agent-clis
COPY cron/agent-cli-updates /etc/cron.d/agent-cli-updates

RUN chmod 0755 /usr/local/sbin/docker-entrypoint /usr/local/sbin/update-agent-clis /usr/local/bin/agent-shell \
    && usermod --shell /usr/local/bin/agent-shell agent \
    && printf '%s\n' /usr/local/bin/agent-shell >> /etc/shells \
    && chmod 0644 /etc/cron.d/agent-cli-updates \
    && touch /var/log/agent-cli-updates.log \
    && node --version \
    && npm --version \
    && git --version \
    && gh --version \
    && glab --version \
    && jq --version \
    && curl --version \
    && tmux -V \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspaces
EXPOSE 22 7777
VOLUME ["/workspaces"]
ENTRYPOINT ["/usr/local/sbin/docker-entrypoint"]
