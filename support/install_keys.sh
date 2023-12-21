#!/usr/bin/env bash

set -eu

# when called, find script directory and run everything except ourselves.
# http://mywiki.wooledge.org/BashFAQ/028
# I know damn well it gives me only the first element but I'm not sure all versions of bash have this as an _array_
# shellcheck disable=SC2128
{
  if [[ -s "${BASH_SOURCE:-}" ]] && [[ -x "${BASH_SOURCE:-}" ]]; then
    # we found ourselves, do the needful.
    source_dir="$(dirname "$(readlink -f "${BASH_SOURCE:-}")")/.."
  fi
}

# go be nice and put errors to stderr
err_msg () {
  printf '%s\n' "${1}" 1>&2
}

# bail if unset
[[ -z "${source_dir:-}" ]] && { err_msg "failed to find self" ; exit 255 ; }

# box for any gpg keys we touched during operation
gpg_keys=()

check_gpg () {
  type gpg 2>/dev/null 1>&2 || { err_msg "failed to find gpg" ; exit 1 ; }
}

# these two are designed to be very simple and very stupid so we can't _break the self build_
install_installergpg () {
  check_gpg
  gpg_keys=("${gpg_keys[@]}" "46265C65A19FDBAC1F8EAA14A54EBDAE914521F8")
  gpg --import "${source_dir}"/gpg/46265C65A19FDBAC1F8EAA14A54EBDAE914521F8.asc || exit 1
}

install_installertrust () {
  install_installergpg
  gpg --import-ownertrust "${source_dir}"/gpg/46265C65A19FDBAC1F8EAA14A54EBDAE914521F8.ownertrust || exit 1
}

case "${1:-}" in
  installersign) install_installergpg ;;
  installersign-ownertrust) install_installertrust ;;
  changelog) cat "${source_dir}/changelog.txt" ;;
  *)
cat << _EOF_ 1>&2
please select an action to run
  installersign            - import the signing key for this installer into gpg
  installersign-ownertrust - import the owner trust (and key) for this installer into gpg
  changelog                - show changelog
_EOF_
  exit 1
  ;;
esac

[[ "${gpg_keys[1]:-}" ]] && { gpg --check-sigs "${gpg_keys[@]}" ; }

# by the time we got here, we should be...fine.
exit 0
