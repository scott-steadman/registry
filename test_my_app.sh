#!/bin/sh

# Show which tests are being run and their results
export TEST_OPTS="--verbose --no-show-detail-immediately"
#export TEST_OPTS="--verbose --no-show-detail-immediately --stop-on-failure"

bundle config --local build.sqlite3 "--enable-system-libraries"
bundle config --local clean true
bundle config --local path vendor/bundle
bundle config --local without vscode

# The bundler version can change between branches
rm Gemfile.lock
bundle install

rm -f db/*.sqlite3 public/coverage
bundle exec rails db:create db:migrate
bundle exec rails db:test:prepare
bundle exec rails test

