#!/usr/bin/env bash

set -eu

# allow for debugging the built assembly
[[ "${DEBUG_KEY_INSTALLER:-}" ]] && [[ "${DEBUG_KEY_INSTALLER:-}" != "false" ]] && set -x

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
  local level="${1}"
  local ownertrust
  read -r ownertrust < "${source_dir}"/gpg/46265C65A19FDBAC1F8EAA14A54EBDAE914521F8.ownertrust
  [[ "${ownertrust}" ]] || exit 1
  [[ "${level}" ]] && {
    ownertrust="${ownertrust%:[1-6]:}"
    ownertrust="${ownertrust}:${level}:"
  }
  gpg --import-ownertrust <<< "${ownertrust}" || exit 1
}

get_gpgfiles () {
  local path="${1}" ext="${2}"
  ext="${ext#.}"
  local target="${source_dir}/gpg/${path}"
  [[ -d "${target}" ]] || return 1
  # return the base file names of stuff found
  local candidates name res
  # grab the base file names
  { cd "${target}" && candidates=(*."${ext}") ; }
  for name in "${candidates[@]}" ; do
    [[ -f "${target}/${name}" ]] || continue
    res=("${res[@]}" "${name%."${ext}"}")
  done
  printf '%s\n' "${res[@]}"
}

list_projects () {
  local item
  projects=("${source_dir}/gpg/project"/*)
  for item in "${projects[@]}" ; do
    printf '%s\n' "${item##*/}"
  done
}

install_projectgpg () {
  local project="${1}"
  local handles grip
  # get the file names we're gonna work on
  handles="$(get_gpgfiles "project/${project}" .asc)" || exit 1
  [[ "${handles[0]:-}" ]] || exit 1
  check_gpg
  for grip in "${handles[@]}" ; do
    gpg --import "${source_dir}/gpg/project/${project}/${grip}.asc" || exit 1
    gpg_keys=("${gpg_keys[@]}" "${grip}")
  done
}

install_projecttrust () {
  local project="${1}"
  local level="${2:-}"
  local grip ownertrust otfile
  install_projectgpg "${project}" || exit 1
  handles="$(get_gpgfiles "project/${project}" .ownertrust)" || exit 1
  [[ "${handles[0]:-}" ]] || exit 1
  for grip in "${handles[@]}" ; do
    otfile="${source_dir}/gpg/project/${project}/${grip}.ownertrust"
    [[ -f "${otfile}" ]] || continue
    read -r ownertrust < "${otfile}"
    [[ "${ownertrust}" ]] || return 1
    [[ "${level}" ]] && {
      ownertrust="${ownertrust%:[1-6]:}"
      ownertrust="${ownertrust}:${level}:"
    }
    gpg --import-ownertrust <<< "${ownertrust}" || exit 1
  done
}

git_signcheck () {
  local checkdir="${1:-}"
  [[ "${checkdir:-}" ]] || checkdir="${USER_PWD:-}"
  [[ "${checkdir}" ]] || { err_msg "cannot find user working directory for check" ; exit 2 ; }
  [[ -x "${source_dir}/scripts/git-sigcheck.sh" ]] || { err_msg "cannot find git/gpg check script in archive" ; exit 2 ; }
  { cd "${checkdir}" && "${source_dir}/scripts/git-sigcheck.sh" ; }
}

case "${1:-}" in
  installersign)              install_installergpg ;;
  installersign-ownertrust)   install_installertrust "${2}" ;;
  gpg-listprojects)           list_projects ;;
  gpg-projectkeys)            shift ; install_projectgpg "${@}" ;;
  gpg-projecttrust)           shift ; install_projecttrust "${@}" ;;
  git-signcheck|git-sigcheck) shift ; git_signcheck "${@}" ;;
  changelog)                  cat "${source_dir}/changelog.txt" ;;
  *)
cat << _EOF_ 1>&2
please select an action to run
  installersign                      - import the signing key for this installer into gpg
  installersign-ownertrust (level)   - import the owner trust (and key) for this installer into gpg.
                                       optionally force the installer trust to a specific level (1-6)
  gpg-projectkeys (project)          - import signing keys for a project
  gpg-projecttrust (project) (level) - import owner trust (and keys) for a project
  git-signcheck (directory)          - check commits in a git checkout for GPG signatures in (directory)
                                       (this uses your local git/keying)
  changelog                          - show changelog
_EOF_
  exit 1
  ;;
esac

[[ "${gpg_keys[0]:-}" ]] && { gpg --check-sigs "${gpg_keys[@]}" ; }

# by the time we got here, we should be...fine.
exit 0
