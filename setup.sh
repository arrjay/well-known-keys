#!/usr/bin/env sh
set -x

# I just need the gitconfig to use the signing key...
git config --local user.signingkey 46265C65A19FDBAC1F8EAA14A54EBDAE914521F8
git config --local commit.gpgsign true

# also tell me about the sigs
git config --local log.showsignature true

# if we don't have a global gpg set to pass, but we _have_ pass, wire ourselves up.
passgpg="${HOME}/.password-store/.extendsions/gpg.bash"
gpgprogram="$(git config --get gpg.program)"
case "${gpgprogram}" in
  *pass*) : ;; # we have some pass reference, away
  *)
    [ -x "${passgpg}" ] && {
      git config --local gpg.program "${gpgprogram}"
    }
  ;;
esac
