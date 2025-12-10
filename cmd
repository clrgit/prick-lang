#!/usr/bin/bash

. bash.include

# Usage
#   cmd -t init|setup|build|help OPTS-OR-ARGS
#

USAGE="init|setup|build|help OPTS-OR-ARGS"

PROJECT="gryf"

echo "$1"
if [ "$1" = "-t" -o "$1" = "--time" ]; then
    shift
    TIMECMD="time"
else
    TIMECMD=""
fi

[ $# -ge 1 ] || error "Illegal number of arguments"
CMD=$1; shift

clear
case "$CMD" in
    init)
        [ -f $PROJECT/.safety ] && rm -rf $PROJECT
        eval $TIMECMD bundle exec exe/prick-lang init $PROJECT
        touch $PROJECT/.safety 2>/dev/null || true
        ;;
    setup)
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT setup ${@:-$PROJECT}
        ;;
    teardown)
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT teardown ${@:-$PROJECT}
        ;;
    cd)
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT cd $@
        ;;
    pwd)
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT pwd
        ;;
    build)
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT build "$@"
        ;;
    help)
        eval $TIMECMD bundle exec exe/prick-lang --help
        ;;
    *)
        error "Command not supported '$CMD'"
        ;;
esac

