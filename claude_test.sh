#!/bin/sh

# Usage: time ./claude_test.sh | tee claude.out

# turn on debugging
#set -x

# stop if any command fails
set -e
set -o pipefail

bundle config --local build.sqlite3 "--enable-system-libraries"
bundle config --local clean false
bundle config --local path vendor/bundle
bundle config --local without vscode


# Show which tests are being run and their results
#export TEST_OPTS="--verbose --no-show-detail-immediately"
export TEST_OPTS="--verbose --no-show-detail-immediately --stop-on-failure"

# In case claude made changes to gems
rm -rf Gemfile.lock Gemfile.next.lock vendor/bundle

# Run tests in order: Rails 3.0 first, then Rails 3.1
for run in 'current' 'next'
do
  echo "*** Testing ${run}..." && sleep 2

  rm -f log/test.log

  # Reinstall gems before each test run to ensure correct versions
  if [ "$run" = "next" ]; then
    next bundle _1.17.3_ install
    bx="next bundle _1.17.3_ exec"
  else
    bundle _1.17.3_ install
    bx="bundle _1.17.3_ exec"
  fi

  # Undike for rails 6.1+
  #$bx rails zeitwerk:check

  rm -f db/*.sqlite3
  RAILS_ENV=test $bx rake db:create db:migrate
  RAILS_ENV=test $bx rake test
done
