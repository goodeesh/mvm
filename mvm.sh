#!/bin/bash
# Meteor Version Manager (MVM)
# Similar to nvm but for Meteor versions
# Usage: source mvm.sh

# Configuration
export MVM_DIR="${MVM_DIR:-$HOME/.mvm}"
export MVM_CURRENT="$MVM_DIR/current"
MVM_VERSIONS="$MVM_DIR/versions"

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
  mvm install <version>               Install a specific Meteor version (e.g., 2.12, 3.0)
  mvm install --path <tarball> <name> Install from local tarball
  mvm use <version>                   Switch to a specific Meteor version
  mvm auto                            Auto-detect and switch to project's Meteor version
  mvm check                           Check if current version matches project
  mvm list                            List all installed Meteor versions
  mvm current                         Show currently active Meteor version
  mvm uninstall <version>             Remove a specific Meteor version
  mvm which                           Show path to current Meteor installation
  mvm alias <name> <ver>              Create an alias (e.g., mvm alias default 2.12)
  mvm help                            Show this help message

Examples:
  mvm install 2.12                    Install Meteor 2.12 from official CDN
  mvm install 3.0.4                   Install Meteor 3.0.4 from official CDN
  mvm install --path ~/meteor-2.12-arm64.tar.gz 2.12-arm64
                                      Install from local tarball
  mvm install -p ~/Downloads/meteor.tar.gz 2.12-custom
                                      Install from local tarball
  mvm use 2.12                        Switch to Meteor 2.12
  mvm use 3.0.4                       Switch to Meteor 3.0.4
  mvm alias default 2.12              Set Meteor 2.12 as default
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

# Validate if path contains a valid Meteor installation
mvm_validate_meteor_path() {
    local source_path=$1
    local meteor_exec=""
    
    # Check if it's a directory or tar.gz
    if [ -d "$source_path" ]; then
        meteor_exec="$source_path/meteor"
    else
        echo -e "${RED}Error: Path is not a directory or doesn't exist${NC}"
        return 1
    fi
    
    # Check for meteor executable
    if [ ! -f "$meteor_exec" ] && [ ! -f "$source_path/meteor.original" ]; then
        echo -e "${RED}Error: No meteor executable found${NC}"
        echo "Expected: $meteor_exec"
        return 1
    fi
    
    # Check for dev_bundle (extracted or tarball), .meteor directory, or official bootstrap format
    # Official bootstrap format has packages/ and package-metadata/ at root
    if [ ! -d "$source_path/dev_bundle" ] && \
       [ ! -d "$source_path/.meteor" ] && \
       ! ls "$source_path"/dev_bundle*.tar.gz >/dev/null 2>&1 && \
       ! ([ -d "$source_path/packages" ] && [ -d "$source_path/package-metadata" ]); then
        echo -e "${YELLOW}Warning: No dev_bundle or .meteor directory found${NC}"
        echo "This may not be a complete Meteor installation"
    fi
    
    return 0
}

# Install from local tarball
mvm_install_local() {
    local tarball_path=$1
    local version_name=$2
    
    if [ -z "$tarball_path" ] || [ -z "$version_name" ]; then
        echo -e "${RED}Error: Both tarball path and version name required${NC}"
        echo "Usage: mvm install --path <tarball> <version-name>"
        echo "Example: mvm install --path ~/meteor-2.12.tar.gz 2.12-arm64"
        return 1
    fi
    
    # Expand tilde and make absolute path
    tarball_path="${tarball_path/#\~/$HOME}"
    
    if [ ! -f "$tarball_path" ]; then
        echo -e "${RED}Error: Tarball file not found: $tarball_path${NC}"
        return 1
    fi
    
    mvm_init
    
    local version_dir="$MVM_VERSIONS/$version_name"
    
    if [ -d "$version_dir" ] && [ -f "$version_dir/meteor" ]; then
        echo -e "${YELLOW}Meteor $version_name is already installed${NC}"
        echo "Use 'mvm use $version_name' to activate it"
        return 0
    fi
    
    echo -e "${BLUE}Installing Meteor $version_name from tarball...${NC}"
    
    # Clean up any partial previous install
    rm -rf "$version_dir"
    
    # Extract tarball to temporary location for installation
    echo "📦 Extracting tarball..."
    local temp_extract=$(mktemp -d)
    
    if ! tar -xzf "$tarball_path" -C "$temp_extract" 2>/dev/null; then
        echo -e "${RED}❌ Failed to extract tarball${NC}"
        echo "Make sure the file is a valid gzip-compressed tar archive (.tar.gz)"
        rm -rf "$temp_extract"
        return 1
    fi
    
    # Find the meteor installation in extracted contents
    local source_dir=""
    
    # Check if this is an official bootstrap tarball (has .meteor/ at root)
    if [ -d "$temp_extract/.meteor" ] && [ -x "$temp_extract/.meteor/meteor" ]; then
        # Official Meteor bootstrap format - the .meteor directory IS the installation
        source_dir="$temp_extract/.meteor"
    elif [ -f "$temp_extract/meteor" ] || [ -f "$temp_extract/meteor.original" ]; then
        # Distribution package format (like community ARM64 builds)
        source_dir="$temp_extract"
    else
        # Look for meteor in subdirectories
        local found_dir=$(find "$temp_extract" -name "meteor" -type f -o -name "meteor.original" -type f 2>/dev/null | head -1)
        if [ -n "$found_dir" ]; then
            source_dir=$(dirname "$found_dir")
        else
            echo -e "${RED}❌ Could not find meteor executable in tarball${NC}"
            rm -rf "$temp_extract"
            return 1
        fi
    fi
    
    # Validate the source
    if ! mvm_validate_meteor_path "$source_dir"; then
        rm -rf "$temp_extract"
        return 1
    fi
    
    # Run install-meteor.sh if present (for community builds)
    # This must run BEFORE we move files, in the extracted location
    if [ -f "$source_dir/install-meteor.sh" ]; then
        echo "📦 Running community build installer..."
        chmod +x "$source_dir/install-meteor.sh"
        # Run the install script in non-interactive mode
        if (cd "$source_dir" && bash install-meteor.sh </dev/null 2>&1 | grep -E "✓|✅|❌|Error" || true); then
            echo "✓ Community build installation completed"
        else
            echo -e "${YELLOW}⚠️  Installation script had issues, continuing anyway${NC}"
        fi
    # Fallback: Extract compressed dev_bundle if present
    elif ls "$source_dir"/dev_bundle*.tar.gz >/dev/null 2>&1; then
        echo "📦 Setting up dev_bundle..."
        local dev_bundle_tarball=$(ls "$source_dir"/dev_bundle*.tar.gz | head -1)
        
        # Create dev_bundle directory
        mkdir -p "$source_dir/dev_bundle"
        
        # Extract the dev_bundle
        if tar -xzf "$dev_bundle_tarball" -C "$source_dir/dev_bundle" 2>/dev/null; then
            echo "✓ dev_bundle extracted successfully"
        else
            echo -e "${RED}❌ Failed to extract dev_bundle${NC}"
            rm -rf "$temp_extract"
            return 1
        fi
    fi
    
    echo "📋 Moving installation to MVM directory..."
    
    # Now move the fully-installed directory to MVM versions
    mkdir -p "$MVM_VERSIONS"
    if ! mv "$source_dir" "$version_dir"; then
        echo -e "${RED}❌ Failed to move installation${NC}"
        rm -rf "$temp_extract"
        return 1
    fi
    
    # Clean up temp extraction
    rm -rf "$temp_extract"
    
    # Ensure meteor executable is executable
    if [ -f "$version_dir/meteor" ]; then
        chmod +x "$version_dir/meteor"
    fi
    if [ -f "$version_dir/meteor.original" ]; then
        chmod +x "$version_dir/meteor.original"
    fi
    
    # Post-installation setup for community ARM64 builds
    # These builds have packages/ at root + a wrapper script, and need special handling
    if [ -f "$version_dir/meteor" ] && [ -f "$version_dir/meteor.original" ] && \
       [ -d "$version_dir/packages" ] && [ -d "$version_dir/tools" ]; then
        echo "🔧 Configuring community build for MVM..."
        
        # Fix meteor wrapper to resolve symlinks properly (use pwd -P)
        if grep -q 'SCRIPT_DIR="$(cd "$(dirname "\$0")" && pwd)"' "$version_dir/meteor" 2>/dev/null; then
            sed -i 's/SCRIPT_DIR="$(cd "$(dirname "\$0")" && pwd)"/SCRIPT_DIR="$(cd "$(dirname "\$0")" \&\& pwd -P)"/' "$version_dir/meteor"
            echo "  ✓ Fixed meteor wrapper for symlink support"
        fi
        
        # Ensure .meteor-version file exists
        if [ ! -f "$version_dir/.meteor-version" ]; then
            # Try to extract version number from version_name (e.g., "2.12-arm64" -> "2.12")
            local version_number=$(echo "$version_name" | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "$version_name")
            echo "$version_number" > "$version_dir/.meteor-version"
            echo "  ✓ Created .meteor-version file"
        fi
        
        # Create unipackage.json in the parent versions directory
        # The tools version detection looks for it at getCurrentToolsDir()/../unipackage.json
        if [ ! -f "$MVM_VERSIONS/unipackage.json" ]; then
            local version_number=$(echo "$version_name" | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "$version_name")
            cat > "$MVM_VERSIONS/unipackage.json" << EOF
{
  "name": "meteor-tool",
  "version": "$version_number"
}
EOF
            echo "  ✓ Created unipackage.json metadata"
        fi
        
        # Community ARM64 builds require isopackets directory at root
        # This is normally generated on first use, but we create the structure
        # so meteor knows where to place the files
        echo "  ⏳ Setting up runtime environment..."
        
        # Create isopackets directory structure
        mkdir -p "$version_dir/isopackets"
        
        echo "  ✓ Runtime environment configured"
        echo "  Note: Full runtime data will be initialized automatically on first use"
        
        # The _mvm_update_path function is configured to NOT set METEOR_WAREHOUSE_DIR for these builds
    fi
    
    # Check binary compatibility
    echo "🧪 Checking compatibility..."
    local sys_arch=$(uname -m)
    local sys_os=$(uname -s)
    
    # Check if we can determine the binary type
    # The meteor script itself is just a shell script, so check the actual node binary
    local binary_to_check=""
    local temp_node=""
    
    if [ -f "$version_dir/dev_bundle/bin/node" ]; then
        # dev_bundle already extracted at root
        binary_to_check="$version_dir/dev_bundle/bin/node"
    elif ls "$version_dir"/dev_bundle*.tar.gz >/dev/null 2>&1; then
        # dev_bundle is compressed, extract just the node binary for checking
        local dev_bundle_tarball=$(ls "$version_dir"/dev_bundle*.tar.gz | head -1)
        temp_node=$(mktemp -d)
        
        # Try to extract node binary from tarball
        if tar -xzf "$dev_bundle_tarball" -C "$temp_node" "./bin/node" 2>/dev/null || \
           tar -xzf "$dev_bundle_tarball" -C "$temp_node" "bin/node" 2>/dev/null; then
            if [ -f "$temp_node/bin/node" ]; then
                binary_to_check="$temp_node/bin/node"
            elif [ -f "$temp_node/./bin/node" ]; then
                binary_to_check="$temp_node/./bin/node"
            fi
        fi
    else
        # Official bootstrap format: node is nested in packages/meteor-tool
        local node_binary=$(find "$version_dir" -path "*/dev_bundle/bin/node" 2>/dev/null | head -1)
        if [ -n "$node_binary" ] && [ -f "$node_binary" ]; then
            binary_to_check="$node_binary"
        fi
    fi
    
    local compat_warning=""
    if [ -z "$binary_to_check" ]; then
        echo -e "${YELLOW}⚠️  Could not find node binary to verify compatibility${NC}"
        echo "Installation may not work on your system if architecture doesn't match"
    elif ! command -v file >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  'file' command not available - cannot verify binary compatibility${NC}"
        echo "Install it with: sudo apt-get install file (Debian/Ubuntu) or sudo yum install file (RHEL/CentOS)"
    else
        local file_output=$(file "$binary_to_check")
        
        # Check for OS mismatch
        if [ "$sys_os" = "Darwin" ] && echo "$file_output" | grep -q "ELF"; then
            compat_warning="Linux binary on macOS - aborting install because it will NOT work"
        elif [ "$sys_os" = "Linux" ] && echo "$file_output" | grep -q "Mach-O"; then
            compat_warning="macOS binary on Linux - aborting install because it will NOT work"
        fi
        
        # Check for architecture mismatch
        if [ "$sys_arch" = "x86_64" ] && echo "$file_output" | grep -qE "aarch64|ARM"; then
            compat_warning="${compat_warning:+$compat_warning; }ARM64 binary on x86_64 system"
        elif [[ "$sys_arch" =~ ^(aarch64|arm64)$ ]] && echo "$file_output" | grep -q "x86-64"; then
            compat_warning="${compat_warning:+$compat_warning; }x86_64 binary on ARM64 system"
        fi
    fi
    
    if [ -n "$compat_warning" ]; then
        echo -e "${RED}❌ Incompatible binary: $compat_warning${NC}"
        echo "System: $sys_os $sys_arch"
        echo ""
        echo "This binary will NOT work on your system."
        # Clean up temp node dir if we extracted one
        [ -n "$temp_node" ] && [ -d "$temp_node" ] && rm -rf "$temp_node"
        rm -rf "$version_dir"
        return 1
    else
        echo -e "${GREEN}✅ Meteor $version_name installed successfully${NC}"
        echo ""
        echo "Run 'mvm use $version_name' to start using this version"
        # Clean up temp node dir if we extracted one
        [ -n "$temp_node" ] && [ -d "$temp_node" ] && rm -rf "$temp_node"
        return 0
    fi
}

# Install a specific Meteor version
mvm_install() {
    # Check for --path or -p flag
    local use_local_path=false
    local source_path=""
    local version=$1
    
    if [ "$1" = "--path" ] || [ "$1" = "-p" ]; then
        use_local_path=true
        source_path=$2
        version=$3
        
        if [ -z "$source_path" ] || [ -z "$version" ]; then
            echo -e "${RED}Error: --path requires both path and version name${NC}"
            echo "Usage: mvm install --path <path> <version-name>"
            echo "Example: mvm install --path ~/meteor-2.12.tar.gz 2.12-arm64"
            return 1
        fi
        
        mvm_install_local "$source_path" "$version"
        return $?
    fi
    
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
        
        # Set METEOR_WAREHOUSE_DIR based on installation structure
        # Community builds (packages/ + tools/ at root) auto-detect, don't set METEOR_WAREHOUSE_DIR
        if [ -d "$MVM_CURRENT/packages" ] && [ -d "$MVM_CURRENT/tools" ]; then
            # Community ARM64 build format - has packages/ and tools/ at root
            # These builds auto-detect their location and create .meteor/isopackets on first use
            # Don't set METEOR_WAREHOUSE_DIR - let it auto-detect
            unset METEOR_WAREHOUSE_DIR
        elif [ -d "$MVM_CURRENT/packages" ] && [ -d "$MVM_CURRENT/package-metadata" ]; then
            # Official bootstrap format - warehouse IS the current directory
            export METEOR_WAREHOUSE_DIR="$MVM_CURRENT"
        elif [ -d "$MVM_CURRENT/.meteor" ]; then
            # Traditional format - warehouse is in .meteor subdirectory
            export METEOR_WAREHOUSE_DIR="$MVM_CURRENT/.meteor"
        else
            # Fallback to current directory
            export METEOR_WAREHOUSE_DIR="$MVM_CURRENT"
        fi
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
    current=$(mvm_current_version)
    if [ -n "$current" ]; then
        echo -e "${GREEN}MVM loaded. Current: Meteor $current${NC}"
    else
        echo -e "${BLUE}MVM loaded. Run 'mvm help' for usage${NC}"
    fi
fi
