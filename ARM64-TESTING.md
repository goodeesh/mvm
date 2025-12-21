# Testing Guide: MVM with ARM64 Linux Community Build

## What We Implemented

Added `--path` flag to `mvm install` that supports:

1. **Community/custom builds** (like Linux ARM64)
2. **Official bootstrap tarballs** (for offline install)
3. **Automatic compatibility checking** (prevents installing wrong OS/architecture)

## Test Scenario: Ubuntu ARM64 System

### Prerequisites

- Ubuntu ARM64 system (your OrbStack VM)
- The ARM64 Linux Meteor tarball: `meteor-2.12-arm64-linux-aarch64.tar.gz`

### Test Steps

**1. Install MVM on Ubuntu ARM64:**

```bash
# In your Ubuntu ARM64 system
cd ~
git clone https://github.com/goodeesh/mvm.git
source ~/mvm/mvm.sh
```

**2. Install the ARM64 Community Build:**

```bash
# Copy the tarball to the Ubuntu system first, or use the path
mvm install --path ~/owl-wrap/meteor-2.12-arm64-linux-aarch64.tar.gz 2.12-arm64

# Expected output:
# ✅ Extracts tarball
# ✅ Extracts dev_bundle (automatically)
# ✅ Checks compatibility (should PASS - Linux ARM64 binary on Linux ARM64)
# ✅ Installs successfully
```

**3. Use and Test:**

```bash
mvm use 2.12-arm64
meteor --version
# Should show: Meteor 2.12 ARM64 Linux (Unofficial Community Build)

# Verify warehouse is set correctly
echo $METEOR_WAREHOUSE_DIR
# Should be: /home/ubuntu/.mvm/versions/2.12-arm64
```

**4. Test Compatibility Detection (should REJECT):**

```bash
# Download an official macOS tarball and try to install
curl -L -o /tmp/meteor-macos.tar.gz \
  "https://static.meteor.com/packages-bootstrap/2.16/meteor-bootstrap-os.osx.arm64.tar.gz"

mvm install --path /tmp/meteor-macos.tar.gz 2.16-wrong

# Expected output:
# ❌ Incompatible binary: macOS binary on Linux - aborting install
# Installation should be rejected
```

**5. Test Official Linux Tarball (should ACCEPT):**

```bash
# Download official Linux x86_64 - will fail compatibility but test the flow
curl -L -o /tmp/meteor-linux.tar.gz \
  "https://static.meteor.com/packages-bootstrap/2.16/meteor-bootstrap-os.linux.x86_64.tar.gz"

mvm install --path /tmp/meteor-linux.tar.gz 2.16-x64

# Expected: Compatibility check rejects (x86_64 on ARM64)
```

### What to Verify

✅ **Installation works**: Tarball extracts, dev_bundle unpacks automatically  
✅ **Meteor runs**: `meteor --version` works correctly  
✅ **Compatibility checking**: Rejects wrong OS/architecture  
✅ **Warehouse detection**: `$METEOR_WAREHOUSE_DIR` points to correct location  
✅ **Multiple versions**: Can switch between versions with `mvm use`

### Expected Behavior Summary

| Action                                   | Expected Result            |
| ---------------------------------------- | -------------------------- |
| Install ARM64 Linux build on ARM64 Linux | ✅ Success                 |
| Install macOS build on Linux             | ❌ Rejected (incompatible) |
| Install x86_64 Linux on ARM64 Linux      | ❌ Rejected (incompatible) |
| `meteor --version` after install         | ✅ Works correctly         |
| Switch between versions                  | ✅ Works with `mvm use`    |

## Structural Differences Explained

### Official Bootstrap Tarball

```
.meteor/
  ├── meteor (symlink)
  ├── packages/
  ├── package-metadata/
  └── (everything nested inside .meteor/)
```

### Community ARM64 Build

```
meteor-2.12-arm64-linux-aarch64/
  ├── meteor
  ├── meteor.original
  ├── packages/
  ├── tools/
  ├── dev_bundle_Linux_aarch64_14.21.3.tar.gz  (compressed!)
  └── (files at root level)
```

**Key Difference**: Community builds have compressed dev_bundle that MVM automatically extracts during installation.

## Report Results

Please test and report:

- [ ] ARM64 Linux build installs successfully
- [ ] Meteor commands work correctly
- [ ] Compatibility checking rejects incompatible binaries
- [ ] Can switch between multiple versions
- [ ] Any errors or unexpected behavior
