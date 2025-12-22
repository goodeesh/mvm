# MVM - Meteor Version Manager

Easily install and switch between multiple Meteor versions. Similar to [nvm](https://github.com/nvm-sh/nvm) but for Meteor.

## Features

- ✅ Install multiple Meteor versions side-by-side
- ✅ Switch between versions instantly
- ✅ Auto-detect project's Meteor version
- ✅ Isolated installations (no conflicts)
- ✅ Works on macOS and Linux

## Installation

### Quick Install (recommended)

```bash
curl -o- https://raw.githubusercontent.com/goodeesh/mvm/main/install.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/goodeesh/mvm/main/install.sh | bash
```

## Usage

### Install a Meteor version

**From official Meteor CDN:**

```bash
mvm install 2.16      # Install Meteor 2.16
mvm install 3.0.4     # Install Meteor 3.0.4
```

**From local tarball:**

Useful for community builds (e.g., Linux ARM64), custom Meteor builds, or offline installation.

```bash
# Community/custom builds
mvm install --path ~/meteor-2.12-arm64.tar.gz 2.12-arm64

# Official tarballs (for offline installation)
# Download from: https://static.meteor.com/packages-bootstrap/VERSION/meteor-bootstrap-PLATFORM.tar.gz
# Platforms: os.linux.x86_64, os.osx.x86_64, os.osx.arm64
mvm install -p ~/meteor-bootstrap-os.osx.arm64.tar.gz 2.16-offline
```

MVM automatically detects incompatible binaries by reading the information of the provided nodejs binary inside the meteor tarball (wrong OS/architecture) and prevents installation.

**Link an existing Meteor installation:**

Perfect for custom builds or Meteor installations in non-standard locations.

```bash
# Link a custom ARM64 build
mvm link /home/user/meteor-2.12-arm64 2.12-arm64

# Link a system-wide installation
mvm link /opt/meteor 2.16-system

# Link a development build
mvm link ~/projects/meteor-custom-build 3.0-custom
```

Linked installations are managed by mvm but the original files remain in their location. Updates to the original directory are reflected immediately.

### Switch between versions

```bash
mvm use 2.16          # Switch to Meteor 2.16
mvm use 3.0.4         # Switch to Meteor 3.0.4
```

### Auto-detect project version

When inside a Meteor project directory:

```bash
mvm auto              # Automatically switch to project's Meteor version
mvm check             # Check if current version matches project
```

### List versions

```bash
mvm list              # List installed versions
mvm current           # Show current version
```

### Uninstall a version

```bash
mvm uninstall 2.16    # Remove Meteor 2.16
```

### Unlink a linked version

```bash
mvm unlink 2.12-arm64 # Remove link (original files untouched)
```

### Other commands

```bash
mvm which             # Show path to current Meteor
mvm alias default 3.0 # Create an alias
mvm help              # Show help
```

## How It Works

MVM installs each Meteor version in an isolated directory (`~/.mvm/versions/<version>/`). When you run `mvm use`, it:

1. Updates your `PATH` to point to the selected version
2. Sets `METEOR_WAREHOUSE_DIR` so Meteor uses the correct package cache

This ensures complete isolation between versions with no conflicts.

## Directory Structure

```
~/.mvm/
├── versions/           # Installed Meteor versions
│   ├── 2.16/
│   │   └── .meteor/
│   └── 3.0.4/
│       └── .meteor/
├── current -> versions/3.0.4   # Symlink to active version
├── alias/              # Version aliases
└── mvm.sh              # Main script (if installed via git clone)
```

## Troubleshooting

### Command not found after installation

Make sure MVM is loaded in your shell:

```bash
source ~/.zshrc  # or ~/.bashrc
```

### Wrong Meteor version running

If `meteor --version` shows a different version than expected:

```bash
# Check what MVM thinks is current
mvm current

# Force reload MVM
source ~/.mvm/mvm.sh

# If in a project, auto-switch
mvm auto
```

### Clean up old Meteor installation

If you have a previous Meteor installation:

```bash
# Remove old installation
rm -rf ~/.meteor
sudo rm -f /usr/local/bin/meteor

# Then use MVM to install
mvm install 3.0.4
mvm use 3.0.4
```

## Requirements

- Bash or Zsh shell
- curl (for installation)
- macOS or Linux

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Inspired by [nvm](https://github.com/nvm-sh/nvm) (Node Version Manager).
