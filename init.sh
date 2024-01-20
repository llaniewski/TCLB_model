#!/bin/bash

set -e

GIT_TCLB=.tclb/git_tclb
GIT_OVER=.tclb/git_over

EXC_FILES="README.md"

if ! test -z "$1"; then
    REMOTE="$1"
    shift
fi

BRANCH=master

function finish {
    for i in $EXC_SAVED; do
        if test -f "$EXC_TMP_DIR/$i"; then
            mv "$EXC_TMP_DIR/$i" "$i"
        fi
    done
    if test -d "$GIT_OVER"; then
        if test -d ".git"; then
        mv .git check_me_git
        fi
        mv $GIT_OVER .git
    fi
}

if git tag > /dev/null 2>&1; then
    if git ls-files | grep src/main.cpp; then
        if test -d "$GIT_TCLB"; then
            echo "$GIT_TCLB: already exists"
            exit 1;
        fi
        mv .git $GIT_TCLB
    else       
        if test -d "$GIT_OVER"; then
            echo "$GIT_OVER: already exists"
            exit 1;
        fi
        mv .git $GIT_OVER && trap finish EXIT
    fi
fi

function git_init {
    git -c init.defaultBranch=master init
}

if ! test -d "$GIT_OVER"; then
    git_init
    mv .git "$GIT_OVER"
fi
trap finish EXIT
function gitover {
    git --git-dir=$GIT_OVER "$@"
}

if ! test -d "$GIT_TCLB"; then
    git_init
    mv .git "$GIT_TCLB"
fi
function gittclb {
    git --git-dir=$GIT_TCLB "$@"
}

URL_OVER="$(gitover remote get-url origin 2>/dev/null || true)"
URL_TCLB="$(gittclb remote get-url origin 2>/dev/null || true)"

if test -z "$URL_TCLB"; then
    REMOTE="https://github.com/"
    CREMOTE="$URL_OVER"
    if ! test -z "$CREMOTE"; then
        case "$CREMOTE" in git@github.com*)
            REMOTE="git@github.com:"
        esac
    fi
    REMOTE="${REMOTE}CFD-GO/TCLB.git"
    URL_TCLB="$REMOTE"
    gittclb remote add origin $URL_TCLB
    EXC_TMP_DIR=.tclb/tmp
    EXC_SAVED=""
    for i in $EXC_FILES; do
        if test -f "$i"; then
            mkdir -p "$EXC_TMP_DIR"
            mv "$i" "$EXC_TMP_DIR"
            EXC_SAVED="$EXC_SAVED $i"
        fi
    done
    gittclb pull origin master
    for i in $EXC_FILES; do
        gittclb update-index --assume-unchanged "$i"
    done
fi

echo "remotes:"
echo " - $URL_OVER"
echo " - $URL_TCLB"

gitover config --local include.path '../.tclb/gitconfig'
