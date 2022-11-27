#!/usr/bin/env bash
# --------------------------------------------------------------------------------------------------
# clone-from-tag.sh
#
# Description
#   Clone a repo to the depth of specified tag.
#   This script is published as a github action.
#     https://github.com/marketplace/actions/checkout-from-tag
#
# License
#   GPL-3.0
#
# --------------------------------------------------------------------------------------------------
# Help
# --------------------------------------------------------------------------------------------------

help="\

NAME
      ${0##*/}

SYNOPSIS
      ${0##*/} [-hrtdo]

DESCRIPTION
      Clone a repository to the depth of specified tag.

      The following options are available:

      -h      Print this menu.

      -r      Optional. The repository to clone.
                Default: <action github repository>

      -t      REQUIRED. The tag (or commit hash) to clone to.

      -d      Optional. The target directory to clone into.
                Default: <repository name>

      -o      Optional. Output the detected depth only, without cloning/deepening.
                Default: false

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
while getopts "hr:t:d:o:" opt; do
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
    o)
      output_depth_only="$OPTARG"
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
echo "$tag_depth" > /tmp/tag_depth
echo -e "Tag $tag is at a depth of $tag_depth..."

# Cleanup tmp resources
cd "$start_dir" || exit
rm -rf "$tmp_dir"

# Execute shallow clone
if [[ $output_depth_only == "false" ]]; then
  if [[ "$deepen" == true ]]; then
    echo -e "Deepening $repo to a depth of: $tag_depth...\n"
    git fetch --deepen="$tag_depth"
  else
    echo -e "Cloning $repo to a depth of: $tag_depth...\n"
    git clone --depth="$tag_depth" "$repo" "$dir"
  fi
fi
