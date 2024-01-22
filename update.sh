#!/bin/bash

set -e

GIT_TCLB=.tclb/git_tclb
GIT_OVER=.tclb/git_over
GITIGN_OVER=".overlay.gitignore"
GITIGN_COMB=".tclb/gitignore"
EXC_FILES="README.md"
UPDATE_SUBM=false
PRINT_HOW_TO=false
EXC_TMP_DIR=.tclb/tmp

function parse_url {
    echo ${1} | sed -n -E "s%^(([^:/@.]*://|)([^@/]+@|)([^:/@]+)[:/]([^:/@.][^:@]*)|)(@([^:@.]*)|)\$%\\${2}%p"
}

function check_url {
    if test -z "$2"; then
        echo "no url provided for $1" >&2
        exit -1
    fi
    if test "$2" != "$(parse_url "$2" "0")"; then
        echo "failed to parse url for $1: $2" >&2
        exit -1
    fi
}

function check_match {
    if test -n "$4" && test "$3" != "$4"; then
        echo "$1 $2 is different than the one specified:" >&2
        echo " - $2 in the git repo: $3" >&2
        echo " - $2 wanted: $4" >&2
        exit 1;
    fi
}

WANT_PULL_TCLB=false
WANT_PULL_OVER=false
while test -n "$1"; do
	case "$1" in
	--submodules)
        UPDATE_SUBM=true
        ;;
	-o|--over|--overlay|--overlay-remote)
        shift
        check_url "overlay" "$1"
        WANT_BRANCH_OVER="$(parse_url "$1" "7")"
        WANT_URL_OVER="$(parse_url "$1" "1")"
        ;;
	-t|--tclb|--tclb-remote)
        shift
        check_url "tclb" "$1"
        WANT_BRANCH_TCLB="$(parse_url "$1" "7")"
        WANT_URL_TCLB="$(parse_url "$1" "1")"
        ;;
    -p|--pull-tclb)
        WANT_PULL_TCLB=true
        ;;
    esac
    shift
done

mkdir -p .tclb
mkdir -p "$EXC_TMP_DIR"

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

if test -z "$URL_OVER"; then
    if test -n "$WANT_URL_OVER"; then
        URL_OVER="$WANT_URL_OVER"
        gitover remote add origin $URL_OVER
        WANT_PULL_OVER=true
    fi
else
    check_match "overlay" "remote" "$URL_OVER" "$WANT_URL_OVER"
fi
if test -n "$URL_OVER"; then
    echo "Fetching overlay origin: $URL_OVER"
    gitover fetch origin
else
    PRINT_HOW_TO=true
    echo "No origin in overlay"
fi

BRANCH_OVER="$(gitover branch --show-current 2>/dev/null || true)"

if test -z "$BRANCH_OVER"; then
    if test -n "$WANT_BRANCH_OVER"; then
        BRANCH_OVER="$WANT_BRANCH_OVER"
    else
        BRANCH_OVER="master"
    fi
    WANT_PULL_OVER=true
else
    check_match "overlay" "branch" "$BRANCH_OVER" "$WANT_BRANCH_OVER"
fi

if $WANT_PULL_OVER; then
    echo "Pulling overlay branch: $BRANCH_OVER"
    for i in $EXC_FILES; do
        test -f "$i" && mv "$i" "$EXC_TMP_DIR"
    done
    gitover pull origin $BRANCH_OVER || true
    for i in $EXC_FILES; do
        test -f "$i" || mv "$EXC_TMP_DIR/$i" "$i" 
    done
fi

URL_TCLB="$(gittclb remote get-url origin 2>/dev/null || true)"

if test -z "$URL_TCLB"; then
    if ! test -z "$WANT_URL_TCLB"; then
        TCLB_OVER="$WANT_URL_TCLB"
    else
        case "$URL_OVER" in
        git@github.com*)
            URL_TCLB="git@github.com:CFD-GO/TCLB.git"
            ;;
        *)
            URL_TCLB="https://github.com/CFD-GO/TCLB.git"
            ;;
        esac
    fi
    gittclb remote add origin $URL_TCLB
    WANT_PULL_TCLB=true
else
    check_match "tclb" "remote" "$URL_TCLB" "$WANT_URL_TCLB"
fi
echo "Fetching tclb origin: $URL_TCLB"
gittclb fetch origin

BRANCH_TCLB="$(gittclb branch --show-current 2>/dev/null || true)"

if test -z "$BRANCH_TCLB"; then
    if test -n "$WANT_BRANCH_TCLB"; then
        BRANCH_TCLB="$WANT_BRANCH_TCLB"
    else
        BRANCH_TCLB="master"
    fi
    WANT_PULL_TCLB=true
else
    check_match "tclb" "branch" "$BRANCH_TCLB" "$WANT_BRANCH_TCLB"
fi

if $WANT_PULL_TCLB; then
    echo "Pulling tclb branch: $BRANCH_TCLB"
    EXC_SAVED=""
    for i in $EXC_FILES; do
        if test -f "$i"; then
            mkdir -p "$EXC_TMP_DIR"
            mv "$i" "$EXC_TMP_DIR"
            EXC_SAVED="$EXC_SAVED $i"
        fi
    done
    gittclb pull origin $BRANCH_TCLB
fi
echo "repos:"
echo "  tclb:"
echo "    remote: $URL_TCLB"
echo "    branch: $BRANCH_TCLB"
echo "  overlay:"
echo "    remote: $URL_OVER"
echo "    branch: $BRANCH_OVER"

for i in $EXC_FILES; do
    gittclb update-index --assume-unchanged "$i"
done

echo "# This file is generated by the init.sh script" >$GITIGN_COMB
if test -f ".gitignore"; then
    echo "## .gitignore" >>$GITIGN_COMB
    cat .gitignore >>$GITIGN_COMB
fi
if test -f "$GITIGN_OVER"; then
    echo "## $GITIGN_OVER" >>$GITIGN_COMB
    cat $GITIGN_OVER >>$GITIGN_COMB
fi
comm <(gitover ls-files | sort) <(gittclb ls-files | sort) -13 | sed 's|^|/|' >>$GITIGN_COMB

gitover config --local core.excludesfile "$GITIGN_COMB"
gitover config --local alias.tclb "!git --git-dir=\"$GIT_TCLB\""

if $UPDATE_SUBM; then
    echo "Updating submodules"
    gittclb submodule init
    gittclb submodule update
fi

echo ""
echo "--------------- Overlay ready ---------------"
echo ""
echo "To make git operations on the overlay repo,"
echo "  use the standard 'git ...' command."
echo "To make git operations on the TCLB repo,"
echo "  use the 'git tclb ...'."
if $PRINT_HOW_TO; then
    echo ""
    echo "You can add the url to the overlay repository by:"
    echo "  > git remote add origin git@github.com/user/repo.git"
    echo "  > git pull origin $BRANCH_OVER"
    echo "   or"
    echo "  > $0 --overlay git@github.com/user/repo.git"
fi
