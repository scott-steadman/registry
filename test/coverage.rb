# Coverage can only see files that are loaded after it starts, and `rails test`
# loads the engine -- all of lib/ -- while booting, long before it gets around
# to test_helper.rb.  So this is required from bin/rails too, which is the first
# thing to run and the last point before lib/registry.rb is pulled in.
#
# Require it as early as possible, from wherever tests are started.

return if defined?($SKIP_COVERAGE) || ENV['SKIP_COVERAGE'] == 'true'

require 'simplecov'

SimpleCov.start do
  root File.expand_path('..', __dir__)
  coverage_dir 'public/coverage'

  # The trailing slashes matter: a bare 'config' matches any path segment
  # called config, which silently excluded lib/registry/config.rb.
  skip 'config/'
  skip 'db/'
  skip 'log/'
  skip 'public/'
  skip 'test/'
  skip 'vendor/'
  skip 'Rakefile'
end
