#!/bin/sh

export SKIP_COVERAGE="true"

# Show which tests are being run and their results
export TEST_OPTS="--verbose --no-show-detail-immediately"
#export TEST_OPTS="--verbose --no-show-detail-immediately --stop-on-failure"

bundle config --local build.sqlite3 "--enable-system-libraries"
bundle config --local clean true
bundle config --local path vendor/bundle
bundle config --local without vscode

# Only clean and reinstall if --no-clean is not specified
if [[ "$*" != *--no-clean* ]]; then
  git gc

  rm -rf Gemfile.lock vendor/bundle
  bundle _1.17.3_ install
fi

rm -rf test/dummy/db/*.sqlite3 public/coverage
RAILS_ENV=test bundle _1.17.3_ exec rake app:db:create app:db:migrate
RAILS_ENV=test bundle _1.17.3_ exec rake test
