#!/bin/bash

###
# System Requirements
type aws >/dev/null 2>&1 || { echo "$0: aws-cli not installed" >&2; exit 1; }
###

###
# Context
pushd `dirname $0` > /dev/null
root=$(pwd -P)/..
popd > /dev/null
###

###
# Parameters and options
opts=hd:vD
debug=
[ -z $domain ] && domain=dev.venicegeo.io
verbose=--only-show-errors
src=$root/public

function _usage {
  cat << _USAGE_
  `basename $0` [-$opts]

   -h             you are here
   -d [domain]    specify environment (default: $domain)
   -v             verbose output
   -D             debug mode

_USAGE_
}

while getopts $opts opt; do
  case $opt in
    h)   _usage; exit                                 ;;
    d)   [ -n "$OPTARG" ] && domain="$OPTARG"         ;;
    v)   verbose=                                     ;;
    D)   debug="--dryrun"                             ;;
    ?|*) _usage; exit 2                               ;;
  esac
done
shift $(($OPTIND-1))

dest=s3://$domain

aws s3 sync $verbose $debug --delete --exclude '*.swp' --exclude '.git*' --exclude '*.sh' --exclude ".DS_Store" $src $dest
