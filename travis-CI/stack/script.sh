#!/bin/sh

set -e

. ./travis-CI/dirs.list

set -x

script_build() {
    STACK_YAML=stack-travis.yaml stack build
    STACK_YAML=stack-travis.yaml stack test
}

if [ x"$dirs" = x ]; then
    script_build
else
    for d in $dirs; do
        ( cd $d && script_build )
    done
fi
