#!/usr/bin/env bash

DEFAULT_OPM_VERSION="v1.47.0"
OPM_VERSION=${OPM_VERSION:-"${DEFAULT_OPM_VERSION}"}

download_opm_client() {
  wget "https://github.com/operator-framework/operator-registry/releases/download/${OPM_VERSION}/$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/aarch64/arm64/;s/x86_64/amd64/')-opm" -O opm
  chmod +x opm
  # check the new binary
  ./opm version
}

version_gte() {
  local version1="$1"
  local version2="$2"
  
  # Strip v prefix and compare using printf for lexicographic that works with semver
  version1=$(echo "$version1" | sed 's/^v//')
  version2=$(echo "$version2" | sed 's/^v//')
  
  printf '%s\n' "$version1" "$version2" | sort -V | head -n1 | grep -q "^${version2}$"
}


opm_alpha_params() {
  params=
  if version_gte "$1" "v4.17"; then
    params="--migrate-level=bundle-object-to-csv-metadata"
  fi
  echo "${params}"
}
