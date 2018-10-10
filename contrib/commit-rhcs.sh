#!/bin/bash
set -e

#############
# VARIABLES #
#############
TEMPLATE="$(mktemp /tmp/commmit-rhcs.XXXXXX)"
CURRENT_GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

#############
# FUNCTIONS #
#############
cleanup() {
  rm -f "$TEMPLATE"
  rm -rf /tmp/ceph-container
}

fatal() {
  echo "FATAL ERROR !"
  echo "########################################################"
  echo "$@"
  echo "########################################################"
  exit 1
}

########
# MAIN #
########
trap cleanup EXIT QUIT INT TERM

git fetch || fatal 'Cannot fetch the remote repository'
git reset --hard "origin/$CURRENT_GIT_BRANCH" || fatal "Cannot reset the local directory !"
#shellcheck disable=SC2001
DOWNSTREAM_BRANCH_VERSION=$(echo "$CURRENT_GIT_BRANCH" | sed 's/ceph-\(.*\)-rhel.*/\1/g')

pushd /tmp
  git clone https://github.com/ceph/ceph-container.git -b "stable-$DOWNSTREAM_BRANCH_VERSION"
  pushd ceph-container
    contrib/compose-rhcs.sh
  popd > /dev/null
popd

COMPOSED_DIR=/tmp/ceph-container/staging/luminous-rhel7-7-released-x86_64/composed

if [ ! -d "$COMPOSED_DIR" ]; then
  fatal "There is no composed directory. Looks like the build failed !"
fi

DOCKER_FILE="$COMPOSED_DIR/Dockerfile"
if [ ! -e "$DOCKER_FILE" ]; then
  fatal "$DOCKER_FILE should exists !"
fi

rsync -aHP --delete-before "$COMPOSED_DIR"/* .

#shellcheck disable=SC2035
git add *

cat >> "$TEMPLATE" << EOF
<TBD>: <TBD> for rhbz#<TBD>

<PLEASE ADD COMMENTS HERE>

Also, since the last update, the following commits were applied.
This is not related to the bz but needed to keep the resync in coherency with upstream.

EOF
COMMITS=$(git diff --staged | grep GIT_COMMIT |cut -d '"' -f 2 | sed -e ':a;N;$!ba;s/\n/../g')
git -C  /tmp/ceph-container log "$COMMITS" --oneline --no-decorate >> "$TEMPLATE"

git commit -st "$TEMPLATE"
