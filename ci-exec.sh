#!/bin/bash -xe

BUNDLER_VERSION=1.2.0
GEMSET=ladle

if [ -z $CI_RUBY ]; then
    echo "CI_RUBY must be set"
    exit 1
fi

set +xe
echo "Initializing RVM"
source ~/.rvm/scripts/rvm
set -xe

# On the overnight build, reinstall all gems
if [ `date +%H` -lt 5 ]; then
    set +xe
    echo "Purging gemset to verify that all deps can still be installed"
    rvm --force $CI_RUBY gemset delete $GEMSET
    set -xe
fi

RVM_CONFIG="${CI_RUBY}@${GEMSET}"
set +xe
echo "Switching to ${RVM_CONFIG}"
rvm use $RVM_CONFIG
set -xe

which ruby
ruby -v

set +e
gem list -i bundler -v $BUNDLER_VERSION
if [ $? -ne 0 ]; then
  set -e
  gem install --no-rdoc --no-ri bundler -v $BUNDLER_VERSION
fi
set -e

export TMPDIR=`pwd`/tmp
mkdir -p $TMPDIR

bundle update

bundle exec rake ci:spec --trace
