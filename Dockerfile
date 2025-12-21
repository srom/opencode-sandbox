# Use a lightweight Debian base with Node.js
FROM node:20-slim

# Add arguments for host UID/GID
ARG USER_ID=1000
ARG GROUP_ID=1000

# Install essentials
RUN apt-get update && apt-get install -y \
    curl git ca-certificates sudo \
    && rm -rf /var/lib/apt/lists/*

# Install OpenCode compatibility bridge globally
RUN npm install -g @ai-sdk/openai-compatible

# --- USER SETUP FIX ---
# 1. Delete the existing 'node' user to prevent ID collisions
RUN userdel -r node 2>/dev/null || true

# 2. Handle Group: If GID exists (e.g. 20), rename it; otherwise create it
RUN if getent group "${GROUP_ID}"; then \
      groupmod -n developer $(getent group "${GROUP_ID}" | cut -d: -f1); \
    else \
      groupadd -g "${GROUP_ID}" developer; \
    fi

# 3. Create the user
RUN useradd -l -u "${USER_ID}" -g "${GROUP_ID}" -m -s /bin/bash developer && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
# ----------------------

USER developer
WORKDIR /app

# Set XDG paths for persistence
ENV XDG_CONFIG_HOME="/home/developer/.config"
ENV XDG_DATA_HOME="/home/developer/.local/share"
ENV XDG_CACHE_HOME="/home/developer/.cache"
ENV XDG_STATE_HOME="/home/developer/.local/state"

ENV PATH="/home/developer/.opencode/bin:${PATH}"

# Install OpenCode
RUN curl -fsSL https://opencode.ai/install | bash

ENTRYPOINT ["opencode"]
