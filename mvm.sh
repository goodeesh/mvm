#!/bin/bash
# Meteor Version Manager (MVM)
# Similar to nvm but for Meteor versions
# Usage: source mvm.sh

# Configuration
export MVM_DIR="${MVM_DIR:-$HOME/.mvm}"
export MVM_CURRENT="$MVM_DIR/current"
export MVM_VERSIONS="$MVM_DIR/versions"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize MVM directory structure
mvm_init() {
    mkdir -p "$MVM_VERSIONS"
    mkdir -p "$MVM_DIR/bin"
}

# Print usage information
mvm_help() {
    cat << EOF
Meteor Version Manager (MVM)

Usage:
  mvm install <version>     Install a specific Meteor version (e.g., 2.12, 3.0)
  mvm use <version>         Switch to a specific Meteor version
  mvm auto                  Auto-detect and switch to project's Meteor version
  mvm check                 Check if current version matches project
  mvm list                  List all installed Meteor versions
  mvm current               Show currently active Meteor version
  mvm uninstall <version>   Remove a specific Meteor version
  mvm which                 Show path to current Meteor installation
  mvm alias <name> <ver>    Create an alias (e.g., mvm alias default 2.12)
  mvm help                  Show this help message

Examples:
  mvm install 2.12          Install Meteor 2.12
  mvm install 3.0.4         Install Meteor 3.0.4
  mvm use 2.12              Switch to Meteor 2.12
  mvm use 3.0.4             Switch to Meteor 3.0.4
  mvm alias default 2.12    Set Meteor 2.12 as default
EOF
}

# List all installed Meteor versions
mvm_list() {
    mvm_init
    echo -e "${BLUE}Installed Meteor versions:${NC}"
    
    if [ ! -d "$MVM_VERSIONS" ] || [ -z "$(ls -A "$MVM_VERSIONS" 2>/dev/null)" ]; then
        echo "  (none installed)"
        return 0
    fi
    
    local current_version=$(mvm_current_version)
    
    for version_dir in "$MVM_VERSIONS"/*; do
        if [ -d "$version_dir" ]; then
            local version=$(basename "$version_dir")
            if [ "$version" = "$current_version" ]; then
                echo -e "  ${GREEN}* $version (currently active)${NC}"
            else
                echo "    $version"
            fi
        fi
    done
}

# Get current Meteor version
mvm_current_version() {
    if [ -L "$MVM_CURRENT" ]; then
        basename "$(readlink "$MVM_CURRENT")"
    fi
}

# Show current Meteor version
mvm_current() {
    local version=$(mvm_current_version)
    if [ -n "$version" ]; then
        echo -e "${GREEN}Current: $version${NC}"
        if command -v meteor >/dev/null 2>&1; then
            meteor --version
        fi
    else
        echo "No Meteor version currently active"
        echo "Run 'mvm use <version>' to activate a version"
    fi
}

# Show path to current Meteor
mvm_which() {
    if command -v meteor >/dev/null 2>&1; then
        which meteor
    else
        echo "No Meteor version currently active"
    fi
}

# Install a specific Meteor version
mvm_install() {
    local version=$1
    
    if [ -z "$version" ]; then
        echo -e "${RED}Error: Version required${NC}"
        echo "Usage: mvm install <version>"
        echo "Example: mvm install 2.12"
        return 1
    fi
    
    mvm_init
    
    local version_dir="$MVM_VERSIONS/$version"
    
    if [ -d "$version_dir" ] && [ -f "$version_dir/meteor" ]; then
        echo -e "${YELLOW}Meteor $version is already installed${NC}"
        echo "Use 'mvm use $version' to activate it"
        return 0
    fi
    
    echo -e "${BLUE}Installing Meteor $version...${NC}"
    echo "📦 Using official Meteor installer..."
    
    # Clean up any partial previous install
    rm -rf "$version_dir"
    mkdir -p "$version_dir"
    
    # Backup existing ~/.meteor if present
    local backup_meteor=""
    if [ -d "$HOME/.meteor" ]; then
        backup_meteor=$(mktemp -d)
        mv "$HOME/.meteor" "$backup_meteor/.meteor"
        echo "  (backed up existing ~/.meteor)"
    fi
    
    # Run the official installer with the specified version
    if curl -sSL "https://install.meteor.com/?release=$version" | sh; then
        # Move the installation to our version directory
        if [ -d "$HOME/.meteor" ]; then
            mv "$HOME/.meteor" "$version_dir/.meteor"
            
            # Create symlink to meteor binary for easy access
            if [ -f "$version_dir/.meteor/meteor" ]; then
                ln -sf "$version_dir/.meteor/meteor" "$version_dir/meteor"
                chmod +x "$version_dir/meteor"
                
                # Clean up the launcher script it created
                sudo rm -f /usr/local/bin/meteor 2>/dev/null
                
                echo -e "${GREEN}✅ Meteor $version installed successfully${NC}"
                echo ""
                echo "Run 'mvm use $version' to start using this version"
            else
                echo -e "${RED}❌ Meteor binary not found after installation${NC}"
                rm -rf "$version_dir"
            fi
        else
            echo -e "${RED}❌ Installation directory not found${NC}"
            rm -rf "$version_dir"
        fi
    else
        echo -e "${RED}❌ Failed to install Meteor $version${NC}"
        rm -rf "$version_dir"
    fi
    
    # Restore backup if it existed
    if [ -n "$backup_meteor" ] && [ -d "$backup_meteor/.meteor" ]; then
        mv "$backup_meteor/.meteor" "$HOME/.meteor"
        rm -rf "$backup_meteor"
        echo "  (restored previous ~/.meteor)"
    fi
}

# Switch to a specific Meteor version
mvm_use() {
    local version=$1
    
    if [ -z "$version" ]; then
        echo -e "${RED}Error: Version required${NC}"
        echo "Usage: mvm use <version>"
        echo "Run 'mvm list' to see installed versions"
        return 1
    fi
    
    mvm_init
    
    local version_dir="$MVM_VERSIONS/$version"
    
    if [ ! -d "$version_dir" ]; then
        echo -e "${RED}Meteor $version is not installed${NC}"
        echo "Run 'mvm install $version' to install it"
        return 1
    fi
    
    # Remove old symlink
    rm -f "$MVM_CURRENT"
    
    # Create new symlink
    ln -sf "$version_dir" "$MVM_CURRENT"
    
    # Update PATH to use MVM's current version
    _mvm_update_path
    
    # Clear the shell's command hash so it picks up the new PATH
    hash -r 2>/dev/null || true
    
    echo -e "${GREEN}Now using Meteor $version${NC}"
    
    # Give a short message instead of failing
    if [ -x "$MVM_CURRENT/meteor" ]; then
        # Just verify the symlink works without running it
        "$MVM_CURRENT/meteor" --version
    else
        echo -e "${YELLOW}Warning: Meteor binary not accessible${NC}"
        echo "Try reloading your shell: source ~/.zshrc (or ~/.bashrc)"
    fi
}

# Uninstall a specific Meteor version
mvm_uninstall() {
    local version=$1
    
    if [ -z "$version" ]; then
        echo -e "${RED}Error: Version required${NC}"
        echo "Usage: mvm uninstall <version>"
        return 1
    fi
    
    local version_dir="$MVM_VERSIONS/$version"
    
    if [ ! -d "$version_dir" ]; then
        echo -e "${RED}Meteor $version is not installed${NC}"
        return 1
    fi
    
    local current_version=$(mvm_current_version)
    if [ "$version" = "$current_version" ]; then
        echo -e "${YELLOW}Warning: Uninstalling currently active version${NC}"
        rm -f "$MVM_CURRENT"
        _mvm_update_path
    fi
    
    echo "Removing Meteor $version..."
    rm -rf "$version_dir"
    echo -e "${GREEN}✅ Meteor $version uninstalled${NC}"
}

# Create version alias
mvm_alias() {
    local alias_name=$1
    local version=$2
    
    if [ -z "$alias_name" ] || [ -z "$version" ]; then
        echo -e "${RED}Error: Both alias name and version required${NC}"
        echo "Usage: mvm alias <name> <version>"
        echo "Example: mvm alias default 2.12"
        return 1
    fi
    
    mvm_init
    
    local version_dir="$MVM_VERSIONS/$version"
    
    if [ ! -d "$version_dir" ]; then
        echo -e "${RED}Meteor $version is not installed${NC}"
        echo "Run 'mvm install $version' first"
        return 1
    fi
    
    local alias_dir="$MVM_DIR/alias"
    mkdir -p "$alias_dir"
    
    echo "$version" > "$alias_dir/$alias_name"
    echo -e "${GREEN}Alias '$alias_name' -> $version${NC}"
}

# Update PATH to include current Meteor version and set METEOR_WAREHOUSE_DIR
_mvm_update_path() {
    # Remove any existing MVM paths from PATH
    export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$MVM_DIR" | tr '\n' ':' | sed 's/:$//')
    
    # Add current version to PATH if it exists
    if [ -L "$MVM_CURRENT" ] && [ -d "$MVM_CURRENT" ]; then
        export PATH="$MVM_CURRENT:$PATH"
        # Set METEOR_WAREHOUSE_DIR so meteor knows where its packages are
        export METEOR_WAREHOUSE_DIR="$MVM_CURRENT/.meteor"
    else
        unset METEOR_WAREHOUSE_DIR
    fi
}

# Detect Meteor version from current project
mvm_detect_version() {
    local release_file=".meteor/release"
    if [ -f "$release_file" ]; then
        # Extract version from METEOR@X.Y.Z format
        local version=$(cat "$release_file" | sed 's/METEOR@//')
        echo "$version"
    fi
}

# Auto-switch to project's Meteor version
mvm_auto() {
    local project_version=$(mvm_detect_version)
    
    if [ -z "$project_version" ]; then
        echo -e "${RED}Not in a Meteor project directory${NC}"
        echo "No .meteor/release file found"
        return 1
    fi
    
    local current_version=$(mvm_current_version)
    
    if [ "$project_version" = "$current_version" ]; then
        echo -e "${GREEN}Already using Meteor $project_version${NC}"
        return 0
    fi
    
    local version_dir="$MVM_VERSIONS/$project_version"
    
    if [ ! -d "$version_dir" ]; then
        echo -e "${YELLOW}Project requires Meteor $project_version (not installed)${NC}"
        read -p "Install it now? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mvm_install "$project_version"
        else
            return 1
        fi
    fi
    
    mvm_use "$project_version"
}

# Check if current version matches project (for warnings)
mvm_check() {
    local project_version=$(mvm_detect_version)
    local current_version=$(mvm_current_version)
    
    if [ -z "$project_version" ]; then
        return 0  # Not in a project, no warning needed
    fi
    
    if [ "$project_version" != "$current_version" ]; then
        echo -e "${YELLOW}⚠️  Warning: Project requires Meteor $project_version but using $current_version${NC}"
        echo -e "${YELLOW}   Run 'mvm auto' to switch automatically${NC}"
        return 1
    fi
    return 0
}

# Main command dispatcher
mvm() {
    local command=$1
    shift
    
    case "$command" in
        install)
            mvm_install "$@"
            ;;
        use)
            mvm_use "$@"
            ;;
        auto)
            mvm_auto
            ;;
        check)
            mvm_check
            ;;
        list|ls)
            mvm_list
            ;;
        current)
            mvm_current
            ;;
        which)
            mvm_which
            ;;
        uninstall)
            mvm_uninstall "$@"
            ;;
        alias)
            mvm_alias "$@"
            ;;
        help|--help|-h)
            mvm_help
            ;;
        "")
            mvm_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo "Run 'mvm help' for usage information"
            return 1
            ;;
    esac
}

# Initialize PATH on load
mvm_init
_mvm_update_path

# Show brief info on load
if [ -z "$MVM_SILENT" ]; then
    local current=$(mvm_current_version)
    if [ -n "$current" ]; then
        echo -e "${GREEN}MVM loaded. Current: Meteor $current${NC}"
    else
        echo -e "${BLUE}MVM loaded. Run 'mvm help' for usage${NC}"
    fi
fi
