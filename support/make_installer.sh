#!/usr/bin/env bash

set -eux

MAKESELF_VER=2.4.5

# check the cache or attempt to download the file
gpg --verify "signatures/makeself-${MAKESELF_VER}.run.sig" "cache/makeself-${MAKESELF_VER}.run" || {
  curl -L -o "cache/makeself-${MAKESELF_VER}.run" \
  "https://github.com/megastep/makeself/releases/download/release-${MAKESELF_VER}/makeself-${MAKESELF_VER}.run"
}

# verify the file
gpg --verify "signatures/makeself-${MAKESELF_VER}.run.sig" "cache/makeself-${MAKESELF_VER}.run"

# clean ups for error or completion
exit_commands=()
cleanup () {
  local function
  [ "${exit_commands[0]:-}" ] || return 0
  for function in "${exit_commands[@]}" ; do
    "${function}"
  done
}
trap cleanup EXIT ERR

# get makeself installed somewhere temporary.
chmod +x "cache/makeself-${MAKESELF_VER}.run"
cleanup_makeself_work () {
  [ "${workdir}" ] && rm -rf "${workdir}"
  [ "${makeself_extract_dir}" ] && rm -rf "${makeself_extract_dir}"
}
exit_commands=("${exit_commands[@]}" cleanup_makeself_work)
workdir="$(mktemp -d)"
makeself_extract_dir="$(mktemp -d)"
"./cache/makeself-${MAKESELF_VER}.run" --target "${makeself_extract_dir}" --keep --noexec

# use git archive to push contents into the workdir. use find to filter out things to not publish.
# shellcheck tries to think it's clever about the parens (which are for _find_!)
# shellcheck disable=SC2046
git archive --format=tar HEAD $(find . -path ./.git -prune -o -path ./support -prune -o -path ./cache -o -path ./.ci -prune -o -path ./signatures -prune -o -path ./.github -prune -o \( -type d -wholename '*/*' \) -print) | tar xvf - -C "${workdir}"
