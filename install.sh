#!/bin/bash
# MVM Installer Script
# Usage: curl -o- https://raw.githubusercontent.com/goodeesh/mvm/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MVM_DIR="${MVM_DIR:-$HOME/.mvm}"
MVM_REPO="https://github.com/goodeesh/mvm.git"
MVM_BRANCH="${MVM_BRANCH:-main}"

echo -e "${BLUE}"
echo "  __  ____     ____  __ "
echo " |  \/  \ \   / /  \/  |"
echo " | |\/| |\ \ / /| |\/| |"
echo " | |  | | \ V / | |  | |"
echo " |_|  |_|  \_/  |_|  |_|"
echo ""
echo " Meteor Version Manager"
echo -e "${NC}"

# Detect shell
detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        basename "$SHELL"
    fi
}

# Get shell profile file
get_profile() {
    local shell_name=$(detect_shell)
    case "$shell_name" in
        zsh)
            echo "$HOME/.zshrc"
            ;;
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.profile"
            fi
            ;;
        *)
            echo "$HOME/.profile"
            ;;
    esac
}

# Check for existing Meteor installation
check_existing_meteor() {
    if [ -d "$HOME/.meteor" ]; then
        echo -e "${YELLOW}⚠️  Existing Meteor installation found at ~/.meteor${NC}"
        echo ""
        echo "MVM manages Meteor versions separately. You have two options:"
        echo "  1. Keep it (MVM will work alongside it)"
        echo "  2. Remove it to let MVM fully manage Meteor"
        echo ""
        read -p "Remove existing ~/.meteor? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Removing ~/.meteor..."
            rm -rf "$HOME/.meteor"
            sudo rm -f /usr/local/bin/meteor 2>/dev/null || true
            echo -e "${GREEN}✅ Removed${NC}"
        fi
    fi
}

# Install MVM
install_mvm() {
    echo -e "${BLUE}Installing MVM...${NC}"
    
    # Create temporary directory for clone
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    echo "Cloning MVM repository..."
    if ! git clone --branch "$MVM_BRANCH" --depth 1 "$MVM_REPO" "$temp_dir" 2>/dev/null; then
        echo -e "${RED}Error: Failed to clone MVM repository${NC}"
        echo "URL: $MVM_REPO"
        echo "Make sure the repository is accessible and the branch '$MVM_BRANCH' exists"
        exit 1
    fi
    
    # Create MVM directory
    mkdir -p "$MVM_DIR"
    mkdir -p "$MVM_DIR/versions"
    mkdir -p "$MVM_DIR/alias"
    
    # Copy mvm.sh
    if ! cp "$temp_dir/mvm.sh" "$MVM_DIR/mvm.sh"; then
        echo -e "${RED}Error: Failed to copy mvm.sh${NC}"
        exit 1
    fi
    
    chmod +x "$MVM_DIR/mvm.sh"
    echo -e "${GREEN}✅ MVM installed to $MVM_DIR${NC}"
}

# Configure shell
configure_shell() {
    local profile=$(get_profile)
    
    echo ""
    echo -e "${BLUE}Configuring shell...${NC}"
    
    # Check if already configured
    if grep -q "MVM_DIR" "$profile" 2>/dev/null; then
        echo -e "${YELLOW}MVM already configured in $profile${NC}"
        return
    fi
    
    # Add MVM to profile
    cat >> "$profile" << 'EOF'

# MVM - Meteor Version Manager
export MVM_DIR="$HOME/.mvm"
[ -s "$MVM_DIR/mvm.sh" ] && source "$MVM_DIR/mvm.sh"
EOF
    
    echo -e "${GREEN}✅ Added MVM to $profile${NC}"
}

# Main installation
main() {
    echo "Installing MVM to $MVM_DIR"
    echo ""
    
    check_existing_meteor
    install_mvm
    configure_shell
    
    echo ""
    echo -e "${GREEN}✅ MVM installation complete!${NC}"
    echo ""
    echo "To start using MVM, run:"
    echo ""
    echo -e "  ${YELLOW}source $(get_profile)${NC}"
    echo ""
    echo "Then install a Meteor version:"
    echo ""
    echo -e "  ${YELLOW}mvm install 3.0.4${NC}"
    echo -e "  ${YELLOW}mvm use 3.0.4${NC}"
    echo ""
    echo "For help, run: mvm help"
    echo ""
}

main
