#!/usr/bin/env bash

#set -e
set -u


usage() {
cat <<EOF
  usage: $0 opts

  This script updates all git repos specified at the bottom of this file.

  In the absence of any flags, it runs 'git pull' in each repository. 
  If other flags are given, you must explicitly provide the '-u' option.

  By default, the script checks if the operations you've requested actually
  need to be done (by checking git status). For example, if there's nothing to
  be pushed in repoA but something in repoB, the '-p' option will be ignored
  in repoA but will be used in repoB. To turn off this behavior, use the '-j'
  option. To do every operation, use '-ja'.

  Note that '-C' includes '-c' (though they are not mutually exclusive).

  OPTIONS:
    -h    Show this message
    -a    Shortcut for -Cups
    -j    Don't check if an operation *needs* to happen, just do it.

    -u    Pull from all repos (this is the default action in absense of any flags)
    -p    Push in addition to pulling

    -s    Check the status of each repository

    -c    Commit STAGED changes (for EVERY repo)
    -C    Commit (selectively) ALL changes using 'git add -p', then commit (for EVERY repo)
EOF
}

push=false
stat=false
commit=false
add=false
pull=false
justdoit=false

while getopts "b:aupscChj" opt; do
	case $opt in
    a) pull=true ; push=true ; stat=true ; add=true ; commit=true ;;
    u) pull=true ;;
    p) push=true ;;
    s) stat=true ;;
    c) commit=true ;;
    C) add=true ; commit=true ;;
    j) justdoit=true ;;
    h) usage; exit 0 ;;
    \?) echo "incorrect usage"; usage; echo; exit 1;;
	esac
done

# if any command flags were given, then we 
# don't want to just *assume* that we're updating 
if  ! ($push || $stat || $commit) ; then
    pull=true
fi

# helper functions to pretty-print some text
header(){
    printf '\033[1m\033[34m>>> \033[1m\033[37m%s\033[0m\n' "$1"
}

progress(){
    printf '\033[1m\033[34m... \033[1m\033[37m%s\033[0m\n' "$1"
    something_happened=true # if we're printing some progress, then at least one operation fired 
}

# helper functions to decide whether or not certain 
# git operations (status, push, add, commit) need to be run
should_i_stat(){
    mystatus="$1"
    if [[ `echo $mystatus | grep -ic "nothing to commit (working directory clean)"` == 0 ]]; then
        echo true
    else
        echo false
    fi
}

should_i_push(){
    mystatus="$1"
    if [[ `echo $mystatus | egrep -ic "your branch is .* by .* commit"` != 0 ]]; then 
        echo true
    else 
        echo false
    fi
}

should_i_add(){
    mystatus="$1"
    if [[ `echo $mystatus | grep -ic "changes not staged for commit"` != 0 ]]; then
        echo true
    else 
        echo false
    fi
}

should_i_commit(){
    mystatus="$1"
    if [[ `echo $mystatus | grep -ic "changes to be committed"` != 0 ]]; then
        echo true
    else
        echo false
    fi
}

# main function that actually operates on a specified git repository
gitit(){
    repo=$1
    cd $repo || exit 1

    # determine which operations we're actually going to do / show to the user
    if $justdoit ; then
        should_stat=true
        should_push=true
        should_add=true
        should_commit=true
    else
        mystatus=`git status`
        should_stat=`should_i_stat "$mystatus"`
        should_push=`should_i_push "$mystatus"`
        should_add=`should_i_add "$mystatus"`
        should_commit=`should_i_commit "$mystatus"`
    fi

    # if we don't need to do anything, then jump out of the function here!
    if ! ( ($stat && $should_stat) \
        || ($push && $should_push) \
        || ($add && $should_add) \
        || ($commit && $should_commit) \
        || $pull) ; then
        return
    fi

    header "$repo" # pretty-print the repo's name

    if $pull ; then
        progress "Updating"
        git pull
    fi

    if $stat && $should_stat ; then
        progress "Getting Status"
        git status
    fi

    if $add && $should_add ; then
        progress "Interactive Add"
        git add -p

        # need to get status again, because add could have changed the state of things
        if ! $justdoit ; then
            mystatus=`git status`
            should_commit=`should_i_commit "$mystatus"`
        fi
    fi

    if $commit && $should_commit ; then
        progress "Committing Staged Changes"
        git commit

        # need to get status again, because commit could have changed the state of things
        if ! $justdoit ; then
            mystatus=`git status`
            should_push=`should_i_push "$mystatus"`
        fi
    fi

    if $push && $should_push ; then
        progress "Pushing Changes"
        git push
    fi

    echo
}

basepath=$HOME/local

something_happened=false # this can be changed in the progress() function

gitit $basepath/class-code
gitit $basepath/config
gitit $basepath/pyutils
gitit $basepath/research
gitit $basepath/scripts
gitit $basepath/side-projects
gitit $basepath/website

# we want to have at least some output, so if nothing happens
# then print this friendly message
if ! $something_happened ; then
    header "All good! No changes to make!"
fi

