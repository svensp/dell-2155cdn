{ stdenv, lib, fetchurl, unzip, rpm, cpio, patchelf, pkgsi686Linux }:

stdenv.mkDerivation rec {
  pname = "dell-2155cdn-driver";
  version = "1.0-1";

  # Source: Dell 2155cdn Linux driver package
  # Original URL: https://dl.dell.com/FOLDER00411421M/1/06_2155_Driver_Linux.zip
  # Note: Direct download from Dell may be blocked (403).
  # Options:
  #   1. Host the file on GitHub releases and update the URL below
  #   2. Download manually and use requireFile (see commented code below)
  src = fetchurl {
    url = "https://dl.dell.com/FOLDER00411421M/1/06_2155_Driver_Linux.zip";
    sha256 = "1xz0kd83ndandxwxipqcg1wljc0if208zgckahywxkdsvvajyg8n";
  };

  # Alternative: Use requireFile to force manual download
  # Uncomment this and comment out the fetchurl above if needed:
  # src = requireFile {
  #   name = "06_2155_Driver_Linux.zip";
  #   url = "https://dl.dell.com/FOLDER00411421M/1/06_2155_Driver_Linux.zip";
  #   sha256 = "1xz0kd83ndandxwxipqcg1wljc0if208zgckahywxkdsvvajyg8n";
  #   message = ''
  #     This driver cannot be downloaded automatically.
  #     Please download it manually from:
  #       https://www.dell.com/support/home/de-de/product-support/product/dell-2155cn-multifunction-color-printer/drivers
  #     and add it to the Nix store using:
  #       nix-store --add-fixed sha256 06_2155_Driver_Linux.zip
  #   '';
  # };

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
