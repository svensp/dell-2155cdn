# Dell 2155cdn Color MFP Driver for NixOS

This package provides the proprietary Dell driver for the Dell 2155cdn Color MFP printer on NixOS, with support for **color printing**.

## Why This Package?

The Dell 2155cdn requires proprietary 32-bit filter binaries for full color support. Generic PCL drivers only support grayscale printing. This package:

- ✅ Patches 32-bit binaries for NixOS compatibility
- ✅ Enables full color printing support
- ✅ Automatically configures CUPS with correct paths
- ✅ Works on modern 64-bit NixOS systems

## Installation

### Step 1: Download the Dell driver manually

Due to Dell's download restrictions (403 Forbidden), the driver cannot be downloaded automatically. You must download it manually:

1. Visit the [Dell 2155cdn driver page](https://www.dell.com/support/home/product-support/product/dell-2155cn-multifunction-color-printer/drivers)
2. Download the "Dell 2155cn/cdn Color Laser MFP Driver" for Linux (`06_2155_Driver_Linux.zip`)
3. Add it to the Nix store:
   ```bash
   nix-store --add-fixed sha256 06_2155_Driver_Linux.zip
   ```

### Step 2: Configure NixOS

#### Option 1: Using this repository (recommended)

Add this to your `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

let
  dell2155cdn = pkgs.callPackage (pkgs.fetchFromGitHub {
    owner = "svensp";
    repo = "dell-2155cdn";
    rev = "1.0.0-rc2";  # Use specific tag or commit hash
    sha256 = "0i937nvh72yd1c1763i1c3zmhs6di1i89a2qj7apclqk1lyccb6p";
  } + "/printer-dell-2155cdn.nix") {
    pkgsi686Linux = pkgs.pkgsi686Linux;
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

### Option 2: Local installation

Clone this repository and reference it locally:

```nix
let
  dell2155cdn = pkgs.callPackage /path/to/printer-dell-2155cdn.nix {
    pkgsi686Linux = pkgs.pkgsi686Linux;
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

### Step 3: Rebuild your system

```bash
sudo nixos-rebuild switch
```

### Step 4: Add the printer

You can add the printer via:

**Web interface:**

- Navigate to http://localhost:631
- Go to Administration → Add Printer
- Select your Dell 2155cdn from the list
- Choose the "Dell 2155cdn Color MFP" driver from the dropdown

**Command line:**

```bash
# List available printers on network
lpinfo -v

# Add printer (adjust URI as needed)
lpadmin -p Dell2155cdn -v ipp://YOUR_PRINTER_IP/ipp/print -P /nix/store/.../share/cups/model/Dell/Dell_2155cdn_Color_MFP.ppd.gz -E

# Or let CUPS find the PPD automatically
lpadmin -p Dell2155cdn -v ipp://YOUR_PRINTER_IP/ipp/print -m Dell/Dell_2155cdn_Color_MFP.ppd.gz -E
```

## Testing

Print a test page:

```bash
lp -d Dell2155cdn /etc/nixos/configuration.nix
```

Check printer status:

```bash
lpstat -p Dell2155cdn -l
```

## Troubleshooting

### Check if the driver is available

```bash
lpinfo -m | grep -i dell
```

### View CUPS logs

```bash
journalctl -u cups -f
```

### Check filter permissions

```bash
ls -la /nix/store/*dell-2155cdn*/lib/cups/filter/Dell_2155_Color_MFP/
```

## Notes

- This driver uses 32-bit binaries and requires `pkgsi686Linux` packages
- The PPD files are automatically patched to use the correct Nix store paths
- The 32-bit binaries are patched with proper interpreter and RPATH for NixOS
- Color printing requires the proprietary Dell filters
- The package has been tested and the binaries execute successfully on NixOS
