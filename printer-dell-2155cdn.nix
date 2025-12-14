{ stdenv, lib, unzip, rpm, cpio, patchelf, pkgsi686Linux, driverZip ? null }:

let
  expectedHash = "1xz0kd83ndandxwxipqcg1wljc0if208zgckahywxkdsvvajyg8n";

  driverSrc = if driverZip == null then
    throw ''
      Dell 2155cdn driver file not provided.

      This driver cannot be downloaded automatically due to Dell's download restrictions (403 Forbidden).
      Please download it manually and pass it as a parameter.

      Steps:
        1. Download from: https://www.dell.com/support/home/product-support/product/dell-2155cn-multifunction-color-printer/drivers
        2. Look for "Dell 2155cn/cdn Color Laser MFP Driver" for Linux (06_2155_Driver_Linux.zip)
        3. Place it in your NixOS configuration directory (e.g., /etc/nixos/)
        4. Pass it to this package:

           dell2155cdn = pkgs.callPackage ... {
             pkgsi686Linux = pkgs.pkgsi686Linux;
             driverZip = ./06_2155_Driver_Linux.zip;
           };

      Expected SHA256: ${expectedHash}
    ''
  else
    let
      actualHash = builtins.hashFile "sha256" driverZip;
    in
      if actualHash != expectedHash then
        throw ''
          Dell 2155cdn driver file hash mismatch!

          Expected SHA256: ${expectedHash}
          Actual SHA256:   ${actualHash}

          The provided file does not match the expected Dell 2155cdn driver.
          Please verify you downloaded the correct file from:
            https://www.dell.com/support/home/product-support/product/dell-2155cn-multifunction-color-printer/drivers

          Look for "Dell 2155cn/cdn Color Laser MFP Driver" for Linux (06_2155_Driver_Linux.zip)
        ''
      else
        driverZip;
in

stdenv.mkDerivation rec {
  pname = "dell-2155cdn-driver";
  version = "1.0-1";

  # Source: Dell 2155cdn Linux driver package
  # Note: Direct download from Dell is blocked (403 Forbidden).
  # Users must download manually and pass the file path as driverZip parameter.
  # Hash verification is performed automatically.
  src = driverSrc;

  nativeBuildInputs = [ unzip rpm cpio patchelf ];

  buildInputs = [
    pkgsi686Linux.cups.lib
    pkgsi686Linux.glibc
    pkgsi686Linux.stdenv.cc.cc.lib
  ];

  # Don't strip 32-bit binaries as it might cause issues
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack

    # Extract the ZIP file
    unzip $src

    # Extract the RPM from the Linux subdirectory
    cd Linux
    rpm2cpio Dell-2155-Color-MFP-1.0-1.i686.rpm | cpio -idmv

    runHook postUnpack
  '';

  installPhase = ''
    mkdir -p $out/lib/cups/filter/Dell_2155_Color_MFP
    mkdir -p $out/share/cups/model/Dell
    mkdir -p $out/share/cups/Dell/dlut

    # Copy filter binaries
    cp -r usr/lib/cups/filter/Dell_2155_Color_MFP/* $out/lib/cups/filter/Dell_2155_Color_MFP/

    # Copy PPD files
    cp usr/share/cups/model/Dell/*.ppd.gz $out/share/cups/model/Dell/

    # Copy lookup table
    cp usr/share/cups/Dell/dlut/*.dlut $out/share/cups/Dell/dlut/

    # Fix PPD paths to point to our nix store location
    for ppd in $out/share/cups/model/Dell/*.ppd.gz; do
      gunzip "$ppd"
      ppd_uncompressed="''${ppd%.gz}"

      # Update filter paths in PPD
      sed -i "s|/usr/lib/cups/filter/Dell_2155_Color_MFP|$out/lib/cups/filter/Dell_2155_Color_MFP|g" "$ppd_uncompressed"

      # Update dlut path
      sed -i "s|/usr/share/cups/Dell/dlut|$out/share/cups/Dell/dlut|g" "$ppd_uncompressed"

      gzip "$ppd_uncompressed"
    done
  '';

  postFixup = ''
    # Patch 32-bit binaries with correct interpreter and RPATH
    for binary in $out/lib/cups/filter/Dell_2155_Color_MFP/*; do
      if [ -f "$binary" ] && [ -x "$binary" ]; then
        echo "Patching $binary"
        patchelf --set-interpreter ${pkgsi686Linux.glibc}/lib/ld-linux.so.2 "$binary" || true
        patchelf --set-rpath ${pkgsi686Linux.cups.lib}/lib:${pkgsi686Linux.stdenv.cc.cc.lib}/lib:${pkgsi686Linux.glibc}/lib "$binary" || true
      fi
    done
  '';

  meta = with lib; {
    description = "Dell 2155cdn Color MFP printer driver";
    homepage = "https://www.dell.com";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "i686-linux" ];
    maintainers = [ ];
  };
}
