#!/bin/bash
#
# Unit tests for the list of Omarchy packages the ISO ships in its offline
# mirror. build-iso.sh owns the list and publishes it as OMARCHY_PACKAGES;
# build-omarchy-packages.sh builds exactly what it is handed. Neither script
# can run outside the privileged build container, so each case evaluates the
# real block lifted out of the real file: an edit that renames or moves the
# block fails the extraction rather than passing quietly.

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  local description="$1"
  local detail="${2:-}"

  [[ -n $detail ]] && printf '%s\n' "$detail" >&2
  printf 'not ok - %s\n' "$description" >&2
  exit 1
}

extract() {
  local file="$1" first="$2" last="$3" block
  block=$(awk -v first="$first" -v last="$last" '
    $0 ~ first { inside = 1 }
    inside { print }
    inside && $0 ~ last { exit }
  ' "$file")
  [[ -n $block ]] || fail "found the block in ${file##*/}" "no match for $first"
  printf '%s\n' "$block"
}

publish_block=$(extract "$ROOT/builder/build-iso.sh" \
  '^read -r -a omarchy_extra_packages' '^export OMARCHY_PACKAGES=')
consume_block=$(extract "$ROOT/builder/build-omarchy-packages.sh" \
  '^if .*OMARCHY_PACKAGES' '^fi$')

# The three channel-selected names are set well above the block, so each case
# supplies them the way build-iso.sh has by the time it runs.
publish() {
  OMARCHY_SETTINGS_PACKAGE=omarchy-settings-dev
  OMARCHY_RUNTIME_PACKAGE=omarchy-dev
  OMARCHY_NVIM_PACKAGE=omarchy-nvim
  eval "$publish_block"
}

(
  unset OMARCHY_EXTRA_PACKAGES
  publish
  [[ ${#omarchy_packages[@]} -eq 3 ]] ||
    fail "the default list is the three Omarchy packages" "got ${#omarchy_packages[@]}"
  [[ $OMARCHY_PACKAGES == "omarchy-settings-dev omarchy-dev omarchy-nvim" ]] ||
    fail "the default list keeps build order" "got $OMARCHY_PACKAGES"
)
pass "the default list is the three Omarchy packages, in build order"

(
  OMARCHY_EXTRA_PACKAGES=""
  publish
  [[ ${#omarchy_packages[@]} -eq 3 ]] ||
    fail "an empty OMARCHY_EXTRA_PACKAGES adds nothing" "got ${#omarchy_packages[@]}"
)
pass "an empty OMARCHY_EXTRA_PACKAGES adds no empty entry"

(
  OMARCHY_EXTRA_PACKAGES="omarchy-fleet omarchy-fleet-agent"
  publish
  [[ $OMARCHY_PACKAGES == "omarchy-settings-dev omarchy-dev omarchy-nvim omarchy-fleet omarchy-fleet-agent" ]] ||
    fail "OMARCHY_EXTRA_PACKAGES appends in order" "got $OMARCHY_PACKAGES"
)
pass "OMARCHY_EXTRA_PACKAGES appends to the list"

# What the offline mirror holds and what the online download asks for must be
# complements: every locally built package is withheld, and nothing else is.
(
  OMARCHY_EXTRA_PACKAGES="omarchy-fleet"
  publish
  all_packages=(git gum omarchy-dev omarchy-settings-dev omarchy-nvim omarchy-fleet jq)
  local_package_filters=()
  for local_package_name in "${omarchy_packages[@]}"; do
    local_package_filters+=(-e "$local_package_name")
  done
  mapfile -t remaining < <(
    printf '%s\n' "${all_packages[@]}" | grep -Fxv "${local_package_filters[@]}" || true
  )
  [[ ${remaining[*]} == "git gum jq" ]] ||
    fail "every locally built package is withheld from the online download" "left ${remaining[*]}"
)
pass "every locally built package is withheld from the online download"

(
  OMARCHY_EXTRA_PACKAGES="omarchy-fleet"
  publish
  eval "$consume_block"
  [[ ${#packages[@]} -eq 4 ]] ||
    fail "the packages builder reads the published list" "got ${#packages[@]}"
  [[ ${packages[0]} == omarchy-settings-dev && ${packages[3]} == omarchy-fleet ]] ||
    fail "the packages builder keeps build order" "got ${packages[*]}"
)
pass "the packages builder builds exactly the published list, in build order"

(
  unset OMARCHY_PACKAGES
  OMARCHY_SETTINGS_PACKAGE=omarchy-settings
  OMARCHY_RUNTIME_PACKAGE=omarchy
  OMARCHY_NVIM_PACKAGE=omarchy-nvim
  eval "$consume_block"
  [[ ${packages[*]} == "omarchy-settings omarchy omarchy-nvim" ]] ||
    fail "the packages builder still runs on its own" "got ${packages[*]}"
)
pass "the packages builder falls back to the three when run on its own"

printf '\nall checks passed\n'
