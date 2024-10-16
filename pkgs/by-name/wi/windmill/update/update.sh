#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix jq curl coreutils prefetch-npm-deps nix nix-update nixfmt-rfc-style
# shellcheck shell=bash

set -euo pipefail

old_version=$(nix-instantiate --eval --json -A windmill.version | jq --raw-output)
version=$(curl -s "https://api.github.com/repos/windmill-labs/windmill/releases/latest" | jq --raw-output ".tag_name")
version="${version#v}"

echo "Updating to $version"
if [[ "$old_version" == "$version" ]]; then
    echo "Already up to date!"
    exit 0
fi

raw_source="https://raw.githubusercontent.com/windmill-labs/windmill/v$version"

echo "Fetching frontend npm lock"
old_npm_hash=$(nix-instantiate --eval --json -A windmill.components.frontend.npmDepsHash | jq --raw-output)
lock_file="$(mktemp)"
curl --silent --output "$lock_file" "$raw_source/frontend/package-lock.json"
npm_hash=$(prefetch-npm-deps "$lock_file")

# Update npmDepsHash
sed --expression "s#${old_npm_hash}#${npm_hash}#" \
    --in-place ./pkgs/by-name/wi/windmill/package.nix

echo "Fetching backend cargo lock"
curl --silent --output "$lock_file" "$raw_source/backend/Cargo.lock"
librusty_version=$(grep --after-context 1 'name = "v8"' "$lock_file" | grep 'version' | awk --field-separator '"' '{print $2}')

echo "Fetching librusty"
declare -A rusty_architectures
rusty_architectures["x86_64-linux"]="x86_64-unknown-linux-gnu"
rusty_architectures["aarch64-linux"]="aarch64-unknown-linux-gnu"
rusty_architectures["x86_64-darwin"]="x86_64-apple-darwin"
rusty_architectures["aarch64-darwin"]="aarch64-apple-darwin"

librusty_tmp="$(mktemp)"
cat <<EOF > "$librusty_tmp"
# auto-generated file -- DO NOT EDIT!
{ fetchLibrustyV8 }:
fetchLibrustyV8 {
  # Librusty version must match version of crate "V8" in Cargo.lock
  version = "$librusty_version";
  shas = {
    $(
    for nix_arch in "${!rusty_architectures[@]}"
    do
        rust_arch=${rusty_architectures[${nix_arch}]}
        download_url="https://github.com/denoland/rusty_v8/releases/download/v$librusty_version/librusty_v8_release_$rust_arch.a.gz"
        hash=$(nix-prefetch fetchurl --option experimental-features "nix-command flakes" --urls --expr "[ $download_url ]")
        echo "$nix_arch = \"$hash\";"
    done
    )
  };
}
EOF

nixfmt "$librusty_tmp"
mv "$librusty_tmp" ./pkgs/by-name/wi/windmill/librusty_v8.nix

echo "Handing off further changes to nix-update"
nix-update --version "$version" windmill