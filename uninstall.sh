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
        
        # Unset the mvm function from current session
        unset -f mvm 2>/dev/null || true
        unset -f mvm_init 2>/dev/null || true
        unset -f mvm_list 2>/dev/null || true
        unset -f mvm_current_version 2>/dev/null || true
        unset -f mvm_current 2>/dev/null || true
        unset -f mvm_which 2>/dev/null || true
        unset -f mvm_list_remote 2>/dev/null || true
        unset -f mvm_install 2>/dev/null || true
        unset -f mvm_use 2>/dev/null || true
        unset -f mvm_uninstall 2>/dev/null || true
        unset -f mvm_alias 2>/dev/null || true
        unset -f mvm_detect_version 2>/dev/null || true
        unset -f mvm_auto 2>/dev/null || true
        unset -f mvm_check 2>/dev/null || true
        unset -f _mvm_update_path 2>/dev/null || true
        unset MVM_DIR 2>/dev/null || true
        unset MVM_CURRENT 2>/dev/null || true
        unset MVM_VERSIONS 2>/dev/null || true
        unset METEOR_WAREHOUSE_DIR 2>/dev/null || true
        
        echo -e "${GREEN}✅ Unset MVM functions from current session${NC}"
    else
        echo "Aborted"
        exit 0
    fi
else
    echo "MVM directory not found at $MVM_DIR"
fi

# Remove MVM from shell profiles
remove_from_profile() {
    local profile=$1
    if [ -f "$profile" ]; then
        # Check if MVM is actually in this profile
        if grep -q "MVM\|mvm.sh" "$profile" 2>/dev/null; then
            local temp_file=$(mktemp)
            
            # Remove MVM initialization lines and the comment line before it
            grep -v "# MVM - Meteor Version Manager" "$profile" | \
            grep -v "# Meteor Version Manager (MVM)" | \
            grep -v "export MVM_DIR=" | \
            grep -v '[ -s "$MVM_DIR/mvm.sh" ]' | \
            grep -v '[ -s "/.*mvm.sh" ]' > "$temp_file"
            
            mv "$temp_file" "$profile"
            echo -e "${GREEN}✅ Removed MVM from shell profile"
        fi
    fi
}

remove_from_profile "$HOME/.zshrc"
remove_from_profile "$HOME/.bashrc"
remove_from_profile "$HOME/.bash_profile"
remove_from_profile "$HOME/.profile"

echo ""
echo -e "${GREEN}MVM uninstalled${NC}"

