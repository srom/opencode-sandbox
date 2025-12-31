#!/usr/bin/env bash

function opencode-sandbox() {

  local XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
  local XDG_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

  local MUTED='\033[0;2m'
  local RED='\033[0;31m'
  local ORANGE='\033[38;5;214m'
  local NC='\033[0m'

  # Parse custom environment variable flags (-e VAR)
  local user_env=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e)
        if [[ -n "$2" && "$2" != -* ]]; then
          user_env+=("$2")
          shift 2
          continue
        else
          echo -e "${RED}Error: -e requires a value${NC}"
          return 1
        fi
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  local PROJECT_STATE_DIR="$PWD/.opencode-sandbox"
  local CONTAINER_NAME=""
  local CONTAINER_NAME_FILE="$PROJECT_STATE_DIR/container_name"

    # --- Configuration on first launch ---
    if [[ ! -d "$PROJECT_STATE_DIR" ]]; then
      echo -e ""
      echo -e "  ${ORANGE}OpenCode Container Sandbox${NC}"
      echo -e "  --------------------------"
      echo -e "  • Access restricted to current working directory ONLY: $PWD"
      echo -e "  • System data will be stored in local folder $PROJECT_STATE_DIR"
      echo -e ""
      
      read -p "  Initialize sandbox and proceed? [y/N] " -n 1 -r
      echo ""
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${MUTED}  Aborted.${NC}"
        return 1
      else
        mkdir -p "$PROJECT_STATE_DIR/config" \
                 "$PROJECT_STATE_DIR/share" \
                 "$PROJECT_STATE_DIR/state" \
                 "$PROJECT_STATE_DIR/cache"
        
        # Generate unique container name on first launch
        local slug=$(head -c 500 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 6)
        CONTAINER_NAME="opencode-$(basename "$PWD")-$slug"
        echo "$CONTAINER_NAME" > "$CONTAINER_NAME_FILE"
      fi
      echo "\n"

      local local_config_dir="$PROJECT_STATE_DIR/config"
      local local_share_dir="$PROJECT_STATE_DIR/share"
      
      # Check if existing opencode config files exist and move them over if they do.
      local existing_config=$(ls "$XDG_CONFIG/opencode/opencode".json{,c} 2>/dev/null | head -n 1)
      local existing_agent="$XDG_CONFIG/opencode/agent"
      local existing_auth="$XDG_DATA/opencode/auth.json"
      
      if [[ -n "$existing_config" ]]; then
        echo -e "${MUTED}Copying existing opencode config from ${NC}$existing_config ${MUTED}to ${NC}${local_config_dir}/"
        cp "${existing_config}" "${local_config_dir}/"
      fi

      if [[ -d "$existing_agent" ]]; then
        mkdir -p "${local_config_dir}/agent"
        echo -e "${MUTED}Copying existing agent config from ${NC}$existing_agent ${MUTED}to ${NC}${local_config_dir}/agent"
        cp -r "${existing_agent}/." "${local_config_dir}/agent/"
      fi
      
      if [[ -f "$existing_auth" ]]; then
        echo -e "${MUTED}Copying existing auth config from${NC} $existing_auth ${MUTED}to ${NC}$local_share_dir/auth.json"
        cp "${existing_auth}" "${local_share_dir}/auth.json"
      fi
  fi

  # Load container name if not already set (for existing sandboxes)
  if [[ -z "$CONTAINER_NAME" ]]; then
    CONTAINER_NAME=$(cat "$CONTAINER_NAME_FILE")
  fi

  export DOCKER_CLI_HINTS=false

  # --- Run container (ensure it exists and is running) ---
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    # Create container if it doesn't exist
    echo -e "${MUTED}Creating new sandbox:${NC} $CONTAINER_NAME"

    local IMAGE_NAME_FILE="$XDG_CONFIG/opencode-sandbox/image_name"
    local IMAGE_NAME=""
    if [[ -f "$IMAGE_NAME_FILE" ]]; then
      IMAGE_NAME=$(cat "$IMAGE_NAME_FILE")
    fi

    if [ -z "$IMAGE_NAME" ] || ! docker images -q "$IMAGE_NAME" > /dev/null; then
      echo -e "${RED}Error: Docker image '$IMAGE_NAME' not found.${NC}"
      echo "Please run the installation script to build the sandbox image."
      return 1
    fi

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
    echo -e "${MUTED}Starting sandbox:${NC} $CONTAINER_NAME"
    docker start "$CONTAINER_NAME" > /dev/null
  fi

  # Extract all {env:VAR} references from config
  local env_vars=()
  local config_file=$(ls "$PROJECT_STATE_DIR/config/opencode".json{,c} 2>/dev/null | head -n 1)
  if [[ -n "$config_file" ]]; then
    while IFS= read -r var; do
      if [[ -n "$var" ]]; then
        env_vars+=("$var")
      fi
    # grep extracts tokens -> sed cleans wrappers -> sort -u removes duplicates
    done < <(grep -o '{env:[^}]*}' "$config_file" 2>/dev/null | sed 's/{env://;s/}//' | sort -u)
  fi

  # Pass all found environment variables to docker exec
  # Include custom -e flags provided by user
  local exec_args=()
  for var in "${env_vars[@]}"; do
    if [[ -n "$var" ]]; then
      exec_args+=("-e" "$var")
    fi
  done
  
  # Add user-provided environment variables
  for uvar in "${user_env[@]}"; do
    exec_args+=("-e" "$uvar")
  done

  docker exec \
    "${exec_args[@]}" \
    -it "$CONTAINER_NAME" \
    opencode "$@"
}
