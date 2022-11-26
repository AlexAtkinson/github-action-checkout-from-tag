#!/usr/bin/env bash
# --------------------------------------------------------------------------------------------------
# clone-from-tag.sh
#
# Description
#   Clone a repo to the depth of specified tag.
#
# --------------------------------------------------------------------------------------------------
# Help
# --------------------------------------------------------------------------------------------------

help="\

NAME
      ${0##*/}

SYNOPSIS
      ${0##*/} [-hrtd]

DESCRIPTION
      Clone a repository to the depth of specified tag.

      The following options are available:

      -h      Print this menu.

      -r      Optional. The repository to clone.
                Default: <action github repository>

      -t      REQUIRED. The tag (or commit hash) to clone to.

      -d      Optional. The target directory to clone into.
                Default: <repository name>

EXAMPLES
      Clone bar repo from version 1.2.3 into the /tmp/bar directory.

          ./${0##*/} -r git@github.com/foo/bar.git -t 1.2.3 -d /tmp/bar

"

printHelp() {
  echo -e "$help" >&2
}

# --------------------------------------------------------------------------------------------------
# Sanity
# --------------------------------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
  printHelp
  exit 1
fi

# --------------------------------------------------------------------------------------------------
# Arguments
# --------------------------------------------------------------------------------------------------

OPTIND=1
while getopts "hr:t:d:" opt; do
  case $opt in
    h)
      printHelp
      exit 0
      ;;
    r)
      repo="$OPTARG"
      ;;
    t)
      tag="$OPTARG"
      ;;
    d)
      dir="$OPTARG"
      ;;
    *)
      echo -e "\e[01;31mERROR\e[00m: Invalid argument!"
      printHelp
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

# --------------------------------------------------------------------------------------------------
# Sanity
# --------------------------------------------------------------------------------------------------

if [[ "$repo" == "unset" ]]; then
  deepen=true
  repo="https://github.com/${GITHUB_REPOSITORY}.git"
fi

if [[ "$tag" == "unset" ]]; then
  semverRegex="^[v]?(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$"
  tag="$(git ls-remote --tags "$repo" | awk -F '/' '{print $3}' | grep -E $semverRegex | sort -rV | head -n 1)"
fi

# --------------------------------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------------------------------

start_dir=$(pwd)
tmp_dir="/tmp/$(openssl rand -base64 128 | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)"

# --------------------------------------------------------------------------------------------------
# Main Operations
# --------------------------------------------------------------------------------------------------

# Get full git log
echo -e "\nClone bare repository..."
mkdir $tmp_dir
git clone -q --bare $repo $tmp_dir

# Determine tag depth
cd "$tmp_dir" || exit
echo -e "Determine tag depth..."
lastCommitHash=$(git rev-parse HEAD)
tag_depth="$(($(git log --no-merges --pretty=oneline "$tag".."$lastCommitHash" | wc -l) + 1))"
echo -e "Tag $tag is at a depth of $tag_depth..."

# Cleanup tmp resources
cd "$start_dir" || exit
rm -rf "$tmp_dir"

# Execute shallow clone
echo -e "Cloning $repo to a depth of: $tag_depth...\n"

if [[ "$deepen" == true ]]; then
  git fetch --deepen="$tag_depth"
else
  git clone --depth="$tag_depth" "$repo" "$dir"
fi
