#!/bin/bash
# The script is provided "AS IS" with no warranties.

# You need to setup your package code for downloading the right package.
# You can find this code in your GravityZone - Network->Packages->[Pick the package you want to install via script]->Send Download Links
# Exmple https://cloudgz.gravityzone.bitdefender.com/Packages/MAC/0/AbCdEF/setup_downloader.dmg
package_code="AbCdEf"
#

clean () {
  echo "Cleaining after installation"
  sleep 30
  rm -rf "$2"
  hdiutil detach "$1"
}

if [ $package_code == "AbCdEf" ]; then
  echo "Change the package_code variable!"
  exit 1
fi

# Check if Bitdefender is installed
bitdefender_cert_installed="1.DeveloperIDApplication:BitdefenderSRL(GUNFMW623Y)Expires:2025-04-2415:11:24+0000SHA256Fingerprint:1BD2BC44AB769DF2428F91E55DF8D19D2894616DFAA879F6CF517718968B2271------------------------------------------------------------------------2.DeveloperIDCertificationAuthorityExpires:2027-02-0122:12:15+0000SHA256Fingerprint:7AFC9D01A62F03A2DE9637936D4AFE68090D2DE18D03F29C88CFB0B1BA63587F------------------------------------------------------------------------3.AppleRootCAExpires:2035-02-0921:40:36+0000SHA256Fingerprint:B0B1730ECBC7FF4505142C49F1295E6EDA6BCAED7E2C68C5BE91B5A11001F024"
if [ -e /Library/Bitdefender/AVP/ ] ; then
  if pkgutil --check-signature "/Library/Bitdefender/AVP/product/bin/BDLDaemon.app" | tr -d '[:space:]' | grep -q "$bitdefender_cert_installed"; then
    echo "Bitdefender is already installed"
    exit 0
  else
    echo "!Bitdefender folder exists on the disk, but the signatures is not valid!"
    exit 1
  fi
else
  echo "Bitdender is not on the endpoint - installing."
fi

# Find the arch of the endpoint
arch_name="$(uname -m)"
if [ "$arch_name" = "x86_64" ]; then
    # "Running on Intel"
    dl_link="https://cloudgz.gravityzone.bitdefender.com/Packages/MAC/0/$package_code/Bitdefender_for_MAC.dmg"
    pkg_name="antivirus_for_mac.pkg"
elif [[ "$arch_name" =~ "arm" ]]; then
    # "Running on ARM"
    dl_link="https://cloudgz.gravityzone.bitdefender.com/Packages/MAC/0/$package_code/Bitdefender_for_MAC_ARM.dmg"
    pkg_name="antivirus_for_mac_arm.pkg"
else
    echo "Unknown architecture: $arch_name"
    exit 1
fi

# Create random folder in tmp for installation
random_folder_name="/tmp/$(openssl rand -hex 16)"
echo "Creating tmp folder $random_folder_name"
mkdir -p "$random_folder_name"
if [ $? -ne 0 ] ; then
    echo "Couldn't create the folder in tmp"
    exit 1
fi

# Download package
dmg_file="$random_folder_name/Bitdefender_for_MAC.dmg"
curl -L -f -o "$dmg_file" "$dl_link"
if [ $? -ne 0 ] ; then
    echo "Download of the installation file was not succesful"
    exit 1
fi

# Mount image and install the app
hdutil_ret=`hdiutil attach -nobrowse "$dmg_file"`
if [ $? -ne 0 ] ; then
  echo "Problem with mounting dmg file."
  echo "Path to the DMG file: $dmg_file"
  echo "hdiutil response: $hdutil_ret"
  exit 1
else
  path_to_mount=`perl -ne 'if (/^[^\r\n]*(\/Volumes\/[^\r\n]*)($|[\r\n])/) { print $1 }' <<< $hdutil_ret`
  full_path_to_mount="$path_to_mount/$pkg_name"
fi

# Instalation of the package
bitdefender_cert_install_pkg="CertificateChain:1.DeveloperIDInstaller:BitdefenderSRL(GUNFMW623Y)Expires:2025-04-2415:14:56+0000SHA256Fingerprint:E2B2644789381CD0B3B2DF71F6A99A6A7B77598713E1DE5A3AAF0FD1B3403707------------------------------------------------------------------------2.DeveloperIDCertificationAuthorityExpires:2027-02-0122:12:15+0000SHA256Fingerprint:7AFC9D01A62F03A2DE9637936D4AFE68090D2DE18D03F29C88CFB0B1BA63587F------------------------------------------------------------------------3.AppleRootCAExpires:2035-02-0921:40:36+0000SHA256Fingerprint:B0B1730ECBC7FF4505142C49F1295E6EDA6BCAED7E2C68C5BE91B5A11001F024"
if pkgutil --check-signature "$full_path_to_mount" | tr -d '[:space:]' | grep -q "$bitdefender_cert_install_pkg"; then
  echo "PKG is validated, installing the package"
  sudo installer -package "$full_path_to_mount" -target /
  if [ $? -ne 0 ] ; then
    echo "Problem during installation of the package"
    clean "$path_to_mount" "$random_folder_name"
    exit 1
  else
    clean "$path_to_mount" "$random_folder_name"
    exit 0
  fi
else
  echo "PKG signature is not valid"
  clean "$path_to_mount" "$random_folder_name"
  exit 1
fi
