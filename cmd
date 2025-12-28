#!/usr/bin/bash

. bash.include

# Usage
#   cmd -t init|setup|build|help OPTS-OR-ARGS
#

USAGE="list|init|setup|build|help OPTS-OR-ARGS"

PROJECT="project"

echo "$1"
if [ "$1" = "-t" -o "$1" = "--time" ]; then
    shift
    TIMECMD="time"
else
    TIMECMD=""
fi

[ $# -ge 1 ] || error "Illegal number of arguments"

clear
case "$1" in
    init)
        if [ -d $PROJECT ]; then
            [ -f $PROJECT/.safety ] && rm -rf $PROJECT || error "No .safety file found in $PROJECT"
        fi

        eval $TIMECMD bundle exec exe/prick-lang init $PROJECT
        touch $PROJECT/.safety 2>/dev/null || true
        ;;
    list)
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT list -l
        ;;
    help)
        eval $TIMECMD bundle exec exe/prick-lang --help
        ;;
    *)
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT "$@"
        ;;

#   setup)
#       eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT setup ${@:-$PROJECT}
#       ;;
#   teardown)
#       eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT teardown ${@:-$PROJECT}
#       ;;
#   info)
#       eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT info $@
#       ;;
#   cd)
#       eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT cd $@
#       ;;
#   pwd)
#       eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT pwd
#       ;;
#   build)
#       eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT build "$@"
#       ;;
#   *)
#       error "Command not supported '$CMD'"
#       ;;
esac

