#!/usr/bin/bash

. bash.include

# Usage
#   cmd -t sync|init|setup|build|help OPTS-OR-ARGS
#

USAGE="sync|list|init|setup|build|help OPTS-OR-ARGS"

PROJECT="project"
SAMPLE="sample"

function sync() {
    local srcdir=$SAMPLE
    local dstdir=$PROJECT/schema
    local src
    local dst
    local base

    [ -d "$srcdir" ] || error "Can't find source directory '$srcdir'"
    [ -f "$PROJECT/.safety" ] || error "Can't find safety file '$PROJECT/.safety'"

    for dst in $(find $dstdir -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
        [[ "$dst" =~ /\. ]] && continue
        [ $(basename $dst) = prick ] && continue
        rm -rf $dst
    done

    for dst in $(find $dstdir -mindepth 1 -maxdepth 1 -type f 2>/dev/null); do
        [[ "$dst" =~ /\. ]] && continue
        [ "$dst" = "reflections.yml" ] && continue
        rm -f $dst
    done

    for src in $(find $srcdir -mindepth 1); do
        [[ "$src" =~ /\. ]] && continue
        dst=$dstdir/${src#$srcdir/}

        if [ -d $src ]; then
            mkdir -p $dst
        else
            ln -f $src $dst
        fi
    done
}

if [ "$1" = "-t" -o "$1" = "--time" ]; then
    shift
    TIMECMD="time"
else
    TIMECMD=""
fi

[ $# -ge 1 ] || error "Illegal number of arguments"

[ "$1" = sync ] || clear
case "$1" in
    sync)
        sync
        ;;
    init)
        if [ -d $PROJECT ]; then
            [ -f $PROJECT/.safety ] && rm -rf $PROJECT || error "No .safety file found in $PROJECT"
        fi

        eval $TIMECMD bundle exec exe/prick-lang init $PROJECT
        touch $PROJECT/.safety 2>/dev/null || true

#       sync
        ;;
    list)
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT list -l
        ;;
    help)
        eval $TIMECMD bundle exec exe/prick-lang --help
        ;;
    *)
#       echo eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT "$@"
        eval $TIMECMD bundle exec exe/prick-lang -C $PROJECT "$@"

        ;;
esac

