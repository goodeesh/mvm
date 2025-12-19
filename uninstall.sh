#!/bin/bash
# MVM Uninstaller Script
# Usage: curl -o- https://raw.githubusercontent.com/goodeesh/mvm/main/uninstall.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MVM_DIR="${MVM_DIR:-$HOME/.mvm}"

echo -e "${YELLOW}Uninstalling MVM...${NC}"
echo ""

# Remove MVM directory
if [ -d "$MVM_DIR" ]; then
    read -p "Remove $MVM_DIR and all installed Meteor versions? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$MVM_DIR"
        echo -e "${GREEN}✅ Removed $MVM_DIR${NC}"
    else
        echo "Aborted"
        exit 0
    fi
else
    echo "MVM directory not found at $MVM_DIR"
fi

echo ""
echo -e "${YELLOW}Note: You may want to remove MVM from your shell profile${NC}"
echo ""
echo "Remove these lines from ~/.zshrc or ~/.bashrc:"
echo ""
echo '  # MVM - Meteor Version Manager'
echo '  export MVM_DIR="$HOME/.mvm"'
echo '  [ -s "$MVM_DIR/mvm.sh" ] && source "$MVM_DIR/mvm.sh"'
echo ""
echo -e "${GREEN}MVM uninstalled${NC}"
