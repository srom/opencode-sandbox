#!/bin/zsh

function opencode-sandbox() {
  local IMAGE_NAME="opencode-sandbox"
  local PROJECT_STATE_DIR="$PWD/.opencode-sandbox"
  local CONTAINER_NAME="opencode-$(basename "$PWD")"

  # --- Configuration on first launch ---
  if [[ ! -d "$PROJECT_STATE_DIR" ]]; then
    echo ""
    echo "  \033[1;36mOpenCode Container Sandbox\033[0m"
    echo "  --------------------------"
    echo "  • Access restricted to current working directory ONLY: $PWD"
    echo "  • System data will be stored in local folder $PROJECT_STATE_DIR"
    echo ""
    
    if ! read -q "REPLY?  Initialize sandbox and proceed? [y/N] "; then
      echo "\n  Aborted."
      return 1
    else
      mkdir -p "$PROJECT_STATE_DIR/config" \
               "$PROJECT_STATE_DIR/share" \
               "$PROJECT_STATE_DIR/state" \
               "$PROJECT_STATE_DIR/cache"
    fi
    echo "\n"
  fi
  # ---------------------------------------

  # --- Run container (create if doesn't exist) ---
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Resuming existing sandbox: $CONTAINER_NAME"
    docker start -ai "$CONTAINER_NAME"
  else
    echo "Creating new sandbox: $CONTAINER_NAME"
    docker run -it \
      --name "$CONTAINER_NAME" \
      --hostname "opencode-sandbox" \
      -e USER="$USER" \
      -v "$PWD:/app" \
      -v "$PROJECT_STATE_DIR/config:/home/developer/.config/opencode" \
      -v "$PROJECT_STATE_DIR/share:/home/developer/.local/share/opencode" \
      -v "$PROJECT_STATE_DIR/state:/home/developer/.local/state/opencode" \
      -v "$PROJECT_STATE_DIR/cache:/home/developer/.cache/opencode" \
      $IMAGE_NAME "$@"
    fi
    # ---------------------------------------
}

