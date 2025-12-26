#!/usr/bin/env bash

function opencode-sandbox() {
  local IMAGE_NAME="opencode-sandbox"
  local PROJECT_STATE_DIR="$PWD/.opencode-sandbox"
  local CONTAINER_NAME="opencode-$(basename "$PWD")"
  export DOCKER_CLI_HINTS=false

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

  # --- Run container (ensure it exists and is running) ---
  if ! docker images -q "$IMAGE_NAME" > /dev/null; then
    echo "Building Docker image: $IMAGE_NAME"
    local source_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
    docker build \
      --build-arg USER_ID=$(id -u) \
      --build-arg GROUP_ID=$(id -g) \
      -t "$IMAGE_NAME" \
      "$source_dir"
  fi
  
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Creating new sandbox: $CONTAINER_NAME"
    docker run -d \
      --name "$CONTAINER_NAME" \
      --hostname "opencode-sandbox" \
      -e USER="$USER" \
      -v "$PWD:/app" \
      -v "$PROJECT_STATE_DIR/config:/home/developer/.config/opencode" \
      -v "$PROJECT_STATE_DIR/share:/home/developer/.local/share/opencode" \
      -v "$PROJECT_STATE_DIR/state:/home/developer/.local/state/opencode" \
      -v "$PROJECT_STATE_DIR/cache:/home/developer/.cache/opencode" \
      "$IMAGE_NAME" > /dev/null
  fi

  # Start if stopped (e.g. after reboot)
  if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" != "true" ]]; then
    echo "Starting sandbox: $CONTAINER_NAME"
    docker start "$CONTAINER_NAME" > /dev/null
  fi

  # Extract all {env:VAR} references from config
  local env_vars=()
  local config_file="$PROJECT_STATE_DIR/config/opencode.json"
  if [[ -f "$config_file" ]]; then
    while IFS= read -r var; do
      if [[ -n "$var" ]]; then
        env_vars+=("$var")
      fi
    # grep extracts tokens -> sed cleans wrappers -> sort -u removes duplicates
    done < <(grep -o '{env:[^}]*}' "$config_file" 2>/dev/null | sed 's/{env://;s/}//' | sort -u)
  fi

  # Pass all found environment variables to docker exec
  local exec_args=()
  for var in "${env_vars[@]}"; do
    if [[ -n "$var" ]]; then
      exec_args+=("-e" "$var")
    fi
  done

  docker exec \
    "${exec_args[@]}" \
    -it "$CONTAINER_NAME" \
    opencode "$@"
}
