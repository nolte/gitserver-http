#!/bin/bash

# Initializes Nginx and the git cgi scripts
# for git http-backend through fcgiwrap.
#
# Usage:
#   entrypoint <commands>
#
# Commands:
#   -start    starts the git server (nginx + fcgi)
#
#   -init     turns directories under `/var/lib/initial`
#             into bare repositories at `/var/lib/git`
#

set -o errexit

readonly GIT_PROJECT_ROOT="/var/lib/git"
readonly GIT_INITIAL_ROOT="/var/lib/initial"
readonly GIT_HTTP_EXPORT_ALL="true"
readonly GIT_USER="git"
readonly GIT_GROUP="git"

readonly FCGIPROGRAM="/usr/bin/fcgiwrap"
readonly USERID="nginx"
readonly SOCKUSERID="$USERID"
readonly FCGISOCKET="/var/run/fcgiwrap.socket"

main() {
  mkdir -p $GIT_PROJECT_ROOT

  # Checks if $GIT_INITIAL_ROOT has files
  if [[ $(ls -A ${GIT_INITIAL_ROOT}) ]]; then
    initialize_initial_repositories
  fi
  initialize_services
}

initialize_services() {
  # Check permissions on $GIT_PROJECT_ROOT
  #if [[ ! $(stat -c %A ${GIT_PROJECT_ROOT}) -eq "drwxr-xr-x" ]]; then
    chown -R git:git $GIT_PROJECT_ROOT
    chmod -R 775 $GIT_PROJECT_ROOT
  #fi

  /usr/bin/spawn-fcgi \
    -s $FCGISOCKET \
    -F 4 \
    -u $USERID \
    -g $USERID \
    -U $USERID \
    -G $GIT_GROUP -- \
    "$FCGIPROGRAM"
  exec nginx
}

initialize_initial_repositories() {
  cd $GIT_INITIAL_ROOT
  for dir in $(find . -maxdepth 1 -mindepth 1 -name "*" -type d); do
    echo "Initializing repository $dir"
    init_and_commit $dir
  done
}

init_and_commit() {
  local dir=$1
  local tmp_dir=$(mktemp -d)
  echo "test_init_repo "

  if [[ -d "$dir/.git" ]]; then
    echo "some exising git repo"
    pushd . >/dev/null
    git clone --bare $dir $GIT_PROJECT_ROOT/${dir}.git &>/dev/null
    popd >/dev/null
  else
    echo "simple file import"
    cp -r $dir/* $tmp_dir
    pushd . >/dev/null

    cd $tmp_dir
    git init &>/dev/null
    git add --all . &>/dev/null
    git commit -m "first commit" &>/dev/null
    git clone --bare $tmp_dir $GIT_PROJECT_ROOT/${dir}.git &>/dev/null
    popd >/dev/null
  fi

}

main "$@"
