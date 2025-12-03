
ENV['RAILS_ENV'] = 'test'

#module CaptureRubyWarnings
#  def warn(message)
#    return if message =~ /assigned but unused variable/
#    return if caller[0] =~ /vendor/ || message =~ /vendor/ # Ignore warnings from vendored code
#    super
#  end
#end
#Warning.extend(CaptureRubyWarnings)

if !defined?($SKIP_COVERAGE) && ENV['SKIP_COVERAGE'] != 'true'
  require 'simplecov'
  SimpleCov.start do
    coverage_dir 'public/coverage'
    add_filter 'config'
    add_filter 'db'
    add_filter 'test'
    add_filter 'vendor'
  end
end

require 'pp'
class Object
  def tap_pp(*args)
    pp [*args, self]
    self
  end
end

require_relative "../test/dummy/config/environment"
require_relative 'test_case'

ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end
