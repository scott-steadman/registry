#!/bin/sh

unset RBENV_VERSION
export RBENV_ROOT=/opt/rbenv
export PATH=${RBENV_ROOT}/shims:${PATH}:${RBENV_ROOT}/bin

git gc

bundle config --local build.sqlite3 "--enable-system-libraries"
bundle config --local clean true
bundle config --local path vendor/bundle
bundle config --local without vscode

rm Gemfile.lock
bundle install

# Show which tests are being run and their results
export TEST_OPTS="--verbose --no-show-detail-immediately"
#export TEST_OPTS="--verbose --no-show-detail-immediately --stop-on-failure"
export SKIP_COVERAGE="true"

rm -f db/*.sqlite3
bundle exec rake db:create db:migrate
bundle exec rake db:test:prepare test
