# Dell 2155cdn NixOS Driver Package - Maintenance Guide

This repository contains the NixOS package for the Dell 2155cdn Color MFP printer driver. This guide documents
procedures for maintaining and updating this package.

## Repository Structure

- `printer-dell-2155cdn.nix` - The main Nix derivation for the driver package
- `README.md` - User-facing installation and usage documentation
- `.gitignore` - Excludes IDE files, Nix build results, and backup files

## Key Package Characteristics

- **Driver Version**: 1.0-1 (Dell's official version number)
- **Package Type**: Unfree/proprietary 32-bit Linux driver
- **Manual Download Required**: Dell blocks automatic downloads (403 Forbidden), users must download and pass file path
  as parameter
- **Source File**: `06_2155_Driver_Linux.zip` (ZIP containing RPM package)
- **Architecture**: 32-bit binaries patched to run on 64-bit NixOS
- **Deployment**: File can be version-controlled in private git repositories alongside NixOS configurations

## Updating the Driver (If Dell Releases New Version)

**Note**: The Dell 2155cdn driver is over 13 years old. Updates are unlikely, but these procedures apply to any
packaging changes.

### 1. Download and Verify New Driver

```bash
# Download manually from Dell support page
# Visit: https://www.dell.com/support/home/product-support/product/dell-2155cn-multifunction-color-printer/drivers

# Calculate hash for documentation purposes
nix-hash --type sha256 --base32 --flat 06_2155_Driver_Linux.zip
```

### 2. Verify File Integrity

Keep the expected SHA256 hash documented in the nix file comments for users to verify their download.

### 3. Update printer-dell-2155cdn.nix

Edit the following fields:

- `version` - Update to new Dell version (e.g., "1.1-1")
- Update the expected SHA256 comment if hash changed

### 4. Check for RPM Filename Changes

Extract and inspect the new ZIP:

```bash
unzip -l 06_2155_Driver_Linux.zip
```

If the RPM filename changed in the `Linux/` directory, update line 45 in the `unpackPhase`:

```nix
rpm2cpio Dell-2155-Color-MFP-NEW-VERSION.i686.rpm | cpio -idmv
```

### 5. Verify Internal File Structure

Extract the RPM and verify paths haven't changed:

```bash
mkdir -p /tmp/dell-test
cd /tmp/dell-test
unzip /path/to/06_2155_Driver_Linux.zip
cd Linux
rpm2cpio Dell-2155-Color-MFP-*.rpm | cpio -idmv

# Verify these paths exist:
ls -la usr/lib/cups/filter/Dell_2155_Color_MFP/
ls -la usr/share/cups/model/Dell/
ls -la usr/share/cups/Dell/dlut/
```

If paths changed, update the `installPhase` accordingly.

## Local Testing Before Release

### 1. Build the Package

```bash
# From repository root, with driver file in current directory
nix-build -E 'with import <nixpkgs> {}; callPackage ./printer-dell-2155cdn.nix {
  inherit pkgsi686Linux;
  driverZip = ./06_2155_Driver_Linux.zip;
}'
```

### 2. Verify Build Output

```bash
# Check the result symlink
ls -la result/

# Verify filter binaries exist and are executable
ls -la result/lib/cups/filter/Dell_2155_Color_MFP/

# Verify PPD files
ls -la result/share/cups/model/Dell/

# Verify dlut files
ls -la result/share/cups/Dell/dlut/

# Check PPD paths are correct (should point to /nix/store/...)
zcat result/share/cups/model/Dell/*.ppd.gz | grep -E "(cupsFilter|Dell_2155_Color_MFP|dlut)"
```

### 3. Test Binary Patching

```bash
# Verify binaries have correct interpreter
for f in result/lib/cups/filter/Dell_2155_Color_MFP/*; do
  if [ -f "$f" ] && [ -x "$f" ]; then
    echo "=== $f ==="
    file "$f"
    patchelf --print-interpreter "$f" 2>/dev/null || echo "Not an ELF binary"
    patchelf --print-rpath "$f" 2>/dev/null || echo "No RPATH"
  fi
done
```

### 4. Integration Test in NixOS Configuration

Test in a VM or on the target system:

```nix
# In configuration.nix
let
  dell2155cdn = pkgs.callPackage /path/to/printer-dell-2155cdn.nix {
    pkgsi686Linux = pkgs.pkgsi686Linux;
    driverZip = ./06_2155_Driver_Linux.zip;  # Path to driver file
  };
in
{
  services.printing = {
    enable = true;
    drivers = [ dell2155cdn ];
  };
  nixpkgs.config.allowUnfree = true;
}
```

```bash
sudo nixos-rebuild test

# Verify driver is available in CUPS
lpinfo -m | grep -i dell

# If you have the printer available, add it and print a test page
```

## Creating a New Release

### 1. Ensure All Changes Are Committed

```bash
git status
git add printer-dell-2155cdn.nix README.md
git commit -m "Update Dell 2155cdn driver to version X.Y-Z"
```

### 2. Create and Push Tag

```bash
# Use semantic versioning: MAJOR.MINOR.PATCH
# For driver updates: increment MINOR version
# For packaging fixes: increment PATCH version
# For breaking changes: increment MAJOR version

git tag -a 1.1.0 -m "Release 1.1.0: Update driver to Dell version X.Y-Z"
git push origin main
git push origin 1.1.0
```

### 3. Update README.md with New Release Hash

Calculate the new fetchFromGitHub hash:

```bash
# Use nix-prefetch-url or nix-prefetch-github
nix-prefetch-url --unpack https://github.com/svensp/dell-2155cdn/archive/refs/tags/1.1.0.tar.gz
```

Update the example in README.md (lines 44-45):

```nix
rev = "1.1.0";  # Update to new tag
sha256 = "NEW_HASH_HERE";  # Update with hash from nix-prefetch-url
```

Commit and tag this update:

```bash
git add README.md
git commit -m "Update README with release 1.1.0 hash"
git tag -a -f 1.1.0 -m "Release 1.1.0: Update driver to Dell version X.Y-Z"
git push origin main
git push origin 1.1.0 --force
```

## Handling Manual Download Requirement

The driver file must be downloaded manually because Dell's servers return 403 Forbidden for automated downloads. The
package accepts the file path as a parameter (`driverZip`).

### For Users

Users download the file once and place it alongside their NixOS configuration. Benefits:

- File can be version-controlled in private git repositories
- Configuration is portable - copy to new machines with the config
- More declarative than requireFile approach
- No need to remember nix-store commands

### For Maintainers

When updating documentation:

1. **Verify download URL** - Test that the URL still works manually
2. **Update README** - If Dell changes their support page structure, update the URL
3. **Document expected hash** - Keep SHA256 hash in nix file comments for user verification

### Alternative: Hosting the Driver

If Dell's download becomes completely unavailable, you could host the file on GitHub releases and use `fetchurl`:

```nix
src = fetchurl {
  url = "https://github.com/svensp/dell-2155cdn/releases/download/driver-1.0-1/06_2155_Driver_Linux.zip";
  sha256 = "1xz0kd83ndandxwxipqcg1wljc0if208zgckahywxkdsvvajyg8n";
};
```

**Note**: Verify licensing allows redistribution before hosting the driver yourself.

## Common Maintenance Tasks

### Updating PPD Path Substitutions

If Dell changes internal paths in their PPD files, update the sed commands in `installPhase` (lines 70-73):

```nix
sed -i "s|OLD_PATH|$out/NEW_PATH|g" "$ppd_uncompressed"
```

### Fixing Binary Patching Issues

If binaries fail to execute after updates:

1. Check interpreter path:

   ```bash
   patchelf --print-interpreter result/lib/cups/filter/Dell_2155_Color_MFP/BINARY
   ```

2. Check RPATH:

   ```bash
   patchelf --print-rpath result/lib/cups/filter/Dell_2155_Color_MFP/BINARY
   ldd result/lib/cups/filter/Dell_2155_Color_MFP/BINARY
   ```

3. Add missing libraries to `buildInputs` if needed

4. Verify with:
   ```bash
   nix-shell -p patchelf --run "patchelf --print-interpreter result/lib/cups/filter/Dell_2155_Color_MFP/BINARY"
   ```

### Handling NixOS Version Compatibility

The package uses `pkgsi686Linux` for 32-bit compatibility. If NixOS updates break this:

1. Check NixOS release notes for changes to 32-bit support
2. Test on the new NixOS version
3. Update `buildInputs` if package names changed
4. Update meta.platforms if architectures changed

### Testing on Different NixOS Versions

Use nixos containers or VMs:

```bash
# Using nixos-rebuild with a test configuration
sudo nixos-rebuild build-vm -I nixos-config=./test-configuration.nix

# Run the VM and test printing
./result/bin/run-*-vm
```

## Troubleshooting Build Issues

### Hash Mismatch

If Nix reports hash mismatch:

```
error: hash mismatch in fixed-output derivation
```

Recalculate and update the hash in `src.sha256`.

### RPM Extraction Fails

If `cpio` fails during unpack:

- Verify the ZIP contains the expected RPM file
- Check if Dell changed the internal directory structure
- Update `unpackPhase` paths accordingly

### Binary Patching Fails

If `patchelf` fails in `postFixup`:

- Check that binaries are actually ELF executables: `file BINARY`
- Verify the binaries are 32-bit: `file BINARY | grep 32-bit`
- Check that pkgsi686Linux packages are available

## Version History

- **1.0.0-rc2**: Current release (tag in repository)
- **1.0.0-rc1**: Initial release (tag in repository)

## References

- Dell 2155cdn Driver Download:
  https://www.dell.com/support/home/product-support/product/dell-2155cn-multifunction-color-printer/drivers
- NixOS Manual - requireFile: https://nixos.org/manual/nixpkgs/stable/#requirefile
- NixOS Manual - CUPS: https://nixos.org/manual/nixos/stable/#module-services-printing
