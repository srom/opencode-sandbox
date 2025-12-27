#!/usr/bin/env bash

function opencode-sandbox() {
  local XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
  local IMAGE_NAME_FILE="$XDG_CONFIG/opencode-sandbox/image_name"
  local IMAGE_NAME="opencode-sandbox"

  if [[ -f "$IMAGE_NAME_FILE" ]]; then
    IMAGE_NAME=$(cat "$IMAGE_NAME_FILE")
  fi

  local PROJECT_STATE_DIR="$PWD/.opencode-sandbox"
  local CONTAINER_NAME=""
  local CONTAINER_NAME_FILE="$PROJECT_STATE_DIR/container_name"

  # --- Configuration on first launch ---
  if [[ ! -d "$PROJECT_STATE_DIR" ]]; then
    echo ""
    echo "  \033[1;36mOpenCode Container Sandbox\033[0m"
    echo "  --------------------------"
    echo "  • Access restricted to current working directory ONLY: $PWD"
    echo "  • System data will be stored in local folder $PROJECT_STATE_DIR"
    echo ""
    
    read -p "  Initialize sandbox and proceed? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "  Aborted."
      return 1
    else
      mkdir -p "$PROJECT_STATE_DIR/config" \
               "$PROJECT_STATE_DIR/share" \
               "$PROJECT_STATE_DIR/state" \
               "$PROJECT_STATE_DIR/cache"
      
      # Generate unique container name on first launch
      local raw_slug=$(LC_ALL=C head -c 500 /dev/urandom | tr -dc 'a-z0-9')
      local slug=${raw_slug:0:6}
      CONTAINER_NAME="opencode-$(basename "$PWD")-$slug"
      echo "$CONTAINER_NAME" > "$CONTAINER_NAME_FILE"
    fi
    echo "\n"
  fi

  # Load container name if not already set (for existing sandboxes)
  if [[ -z "$CONTAINER_NAME" ]]; then
    CONTAINER_NAME=$(cat "$CONTAINER_NAME_FILE")
  fi

  export DOCKER_CLI_HINTS=false

  # --- Run container (ensure it exists and is running) ---
  if ! docker images -q "$IMAGE_NAME" > /dev/null; then
    echo -e "\033[0;31mError: Docker image '$IMAGE_NAME' not found.\033[0m"
    echo "Please run the installation script to build the sandbox image."
    return 1
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
