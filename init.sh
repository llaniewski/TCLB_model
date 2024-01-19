#!/bin/bash

set -e

GIT_TCLB=.tclb/git_tclb
GIT_OVER=.tclb/git_over

if ! test -z "$1"; then
    REMOTE="$1"
    shift
fi

BRANCH=master

if git tag > /dev/null 2>&1; then
    if git ls-files | grep src/main.cpp; then
        if test -d "$GIT_TCLB"; then
            echo "$GIT_TCLB: already exists"
            exit 1;
        fi
        mv .git $GIT_TCLB
    else
        function finish {
            if test -d "$GIT_OVER"; then
                if test -d ".git"; then
                mv .git check_me_git
                fi
                mv $GIT_OVER .git
            fi
        }
        if test -d "$GIT_OVER"; then
            echo "$GIT_OVER: already exists"
            exit 1;
        fi
        mv .git $GIT_OVER && trap finish EXIT
    fi
fi

if ! test -d "$GIT_OVER"; then
    git init
    mv .git "$GIT_OVER"
fi
function gitover {
    git --git-dir=$GIT_OVER "$@"
}

if ! test -d "$GIT_TCLB"; then
    git init
    mv .git "$GIT_TCLB"
fi
function gittclb {
    git --git-dir=$GIT_TCLB "$@"
}

URL_OVER="$(gitover remote get-url origin 2>/dev/null || true)"
URL_TCLB="$(gittclb remote get-url origin 2>/dev/null || true)"

echo "remotes:"
echo " - $URL_OVER"
echo " - $URL_TCLB"

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
fi

exit 0

if test -z "$REMOTE"; then
    REMOTE="https://github.com/"
    CREMOTE="$(git remote get-url origin)"
    if ! test -z "$CREMOTE"; then
        case "$CREMOTE" in git@github.com*)
            REMOTE="git@github.com:"
        esac
    fi
    REMOTE="${REMOTE}CFD-GO/TCLB.git"
fi
echo "remote: $REMOTE"


git init
git remote add origin $URL_TCLB
git remote -v
git pull origin master
mv .git .tclb/tclb_git
