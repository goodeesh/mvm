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
````

## Usage

### Install a Meteor version

```bash
mvm install 2.16      # Install Meteor 2.16
mvm install 3.0.4     # Install Meteor 3.0.4
```

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
