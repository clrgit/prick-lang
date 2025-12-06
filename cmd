#!/usr/bin/bash

. bash.include

# Usage
#   cmd init|setup|build|help OPTS-OR-ARGS
#

USAGE="init|setup|build|help OPTS-OR-ARGS"

PROJECT="gryf"

[ $# -ge 1 ] || error "Illegal number of arguments"
CMD=$1; shift

clear
case "$CMD" in
    init)
        [ -f $PROJECT/.safety ] && rm -rf $PROJECT
        bundle exec exe/prick-lang init $PROJECT
        touch $PROJECT/.safety
        ;;
    setup)
        bundle exec exe/prick-lang -C $PROJECT setup $PROJECT
        ;;
    build)
        bundle exec exe/prick-lang -C $PROJECT build "$@"
        ;;
    help)
        bundle exec exe/prick-lang --help
        ;;
    *)
        error "Command not supported '$CMD'"
        ;;
esac

