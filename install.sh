#!/usr/bin/env bash
set -euo pipefail

APP=ocs

MUTED='\033[0;2m'
RED='\033[0;31m'
ORANGE='\033[38;5;214m'
NC='\033[0m'

usage() {
    cat <<EOF
opencode-sandbox (ocs) installer

Usage: install.sh [options]

Options:
    -h, --help              Display this help message
    --local <path>          Install from local directory instead of GitHub
    --install-dir <path>    Install to custom absolute path (default: \$HOME/.opencode-sandbox)
    --no-modify-path        Don't modify shell config files (.zshrc, .bashrc, etc.)

Examples:
    curl -fsSL https://raw.githubusercontent.com/srom/opencode-sandbox/refs/heads/main/install.sh | bash
    ./install.sh --local /path/to/opencode-sandbox --install-dir /opt/opencode-sandbox
EOF
}

local_path=""
install_dir=""
no_modify_path=false

# Check dependencies
for cmd in curl unzip docker; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: Required command '$cmd' is not installed.${NC}"
        exit 1
    fi
done

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --local)
            if [[ -n "${2:-}" ]]; then
                local_path="$2"
                shift 2
            else
                echo -e "${RED}Error: --local requires a path argument${NC}"
                exit 1
            fi
            ;;
        --install-dir)
            if [[ -n "${2:-}" ]]; then
                install_dir="$2"
                shift 2
            else
                echo -e "${RED}Error: --install-dir requires a path argument${NC}"
                exit 1
            fi
            ;;
        --no-modify-path)
            no_modify_path=true
            shift
            ;;
        *)
            echo -e "${ORANGE}Warning: Unknown option '$1'${NC}" >&2
            shift
            ;;
    esac
done

# Check OS compatibility
if [[ "$(uname -s)" =~ ^(MINGW|MSYS|CYGWIN) ]]; then
  echo -e "${RED}Error: Windows is not currently supported.${NC}"
  exit 1
fi

if [[ -z "$install_dir" ]]; then
    INSTALL_DIR="$HOME/.opencode-sandbox"
else
    INSTALL_DIR="$install_dir"
fi

BIN_DIR="$INSTALL_DIR/bin"
mkdir -p "$BIN_DIR"

SOURCE_DIR="$INSTALL_DIR/source"
[ -d "$SOURCE_DIR" ] && rm -r $SOURCE_DIR
mkdir "$SOURCE_DIR"

# Determine source
if [[ -n "$local_path" ]]; then
    if [[ ! -d "$local_path" ]]; then
        echo -e "${RED}Error: Local path '$local_path' does not exist.${NC}"
        exit 1
    fi
    echo -e "${MUTED}Installing from local directory: ${NC}$local_path"

    # Move files
    cp -r "$local_path/." "$SOURCE_DIR/"
else
    echo -e "${MUTED}Downloading latest version from GitHub...${NC}"
    
    # Ensure cleanup happens even if script fails
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    zip_file="$tmp_dir/main.zip"
    curl -fsSL -o "$zip_file" "https://github.com/srom/opencode-sandbox/archive/refs/heads/main.zip"
    unzip -q "$zip_file" -d "$tmp_dir"
    
    # Move files
    cp -r "$tmp_dir/opencode-sandbox-main/." "$SOURCE_DIR/"
fi

# Create entry point script
cat > "$BIN_DIR/$APP" << EOF
#!/usr/bin/env bash
set -euo pipefail
source "$SOURCE_DIR/opencode-sandbox.sh"
opencode-sandbox "\$@"
EOF

chmod 755 "$BIN_DIR/$APP"

# Build Docker image
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_DIR="$XDG_CONFIG/opencode-sandbox"
mkdir -p "$CONFIG_DIR"

# Cleanup previous image
IMAGE_NAME_FILE="$CONFIG_DIR/image_name"
if [ -f "$IMAGE_NAME_FILE" ]; then
    PREV_IMAGE=$(cat "$IMAGE_NAME_FILE")
    if [ -n "$PREV_IMAGE" ]; then
        echo -e "${MUTED}Removing previous image: ${NC}$PREV_IMAGE"
        # We use '|| true' to ensure the script doesn't exit if deletion fails
        docker image rm "$PREV_IMAGE" 2>/dev/null || true
    fi
fi

# Generate unique image name
SLUG=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | dd bs=1 count=6 2>/dev/null)
IMAGE_NAME="opencode-sandbox-$SLUG"

echo -e "${MUTED}Building Docker image: ${NC}$IMAGE_NAME"
docker build \
    --build-arg USER_ID=$(id -u) \
    --build-arg GROUP_ID=$(id -g) \
    -t "$IMAGE_NAME" \
    "$SOURCE_DIR"

echo "$IMAGE_NAME" > "$IMAGE_NAME_FILE"

# Add to PATH in shell profile
current_shell=$(basename "$SHELL")

case $current_shell in
    fish)
        config_files="$XDG_CONFIG/fish/config.fish $HOME/.config/fish/config.fish"
        # Fish syntax written to file, not executed
        add_cmd="fish_add_path $BIN_DIR"
        ;;
    zsh)
        config_files="$HOME/.zshrc $HOME/.zshenv $XDG_CONFIG/zsh/.zshrc"
        add_cmd="export PATH=\"$BIN_DIR:\$PATH\""
        ;;
    bash)
        config_files="$HOME/.bashrc $HOME/.bash_profile $HOME/.profile"
        add_cmd="export PATH=\"$BIN_DIR:\$PATH\""
        ;;
    *)
        config_files="$HOME/.bashrc $HOME/.profile"
        add_cmd="export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac

if [[ "$no_modify_path" != "true" ]]; then
    config_file=""
    for file in $config_files; do
        if [[ -f "$file" ]] && [[ -w "$file" ]]; then
            config_file="$file"
            break
        fi
    done

    if [[ -z "$config_file" ]]; then
        echo -e "${ORANGE}No writable shell config found. Manually add to PATH:${NC}"
        echo -e "  $add_cmd"
    # Check if the line specifically exists
    elif ! grep -Fq "$BIN_DIR" "$config_file"; then
        echo -e "\n# $APP" >> "$config_file"
        echo "$add_cmd" >> "$config_file"
        echo -e "${MUTED}Added to PATH in ${NC}$config_file"
        echo -e "${ORANGE}Restart your shell or run 'source $config_file' to use the command.${NC}"
    else
        echo -e "${MUTED}Shell config already updated.${NC}"
    fi
fi

# Success message
echo -e ""
echo -e "${MUTED}$APP installed successfully to: ${NC}$INSTALL_DIR"
echo -e "${MUTED}Run \"$APP\" in any project directory to start the sandbox."
echo -e ""
echo -e "${MUTED}For more info: https://github.com/srom/opencode-sandbox ${NC}"
