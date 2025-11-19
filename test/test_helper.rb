require 'test/unit'

ENV['RAILS_ENV'] = 'test'

module CaptureRubyWarnings
  def warn(message)
    return if message =~ /assigned but unused variable/
    return if caller[0] =~ /vendor/ || message =~ /vendor/ # Ignore warnings from vendored code
    super
  end
end
Warning.extend(CaptureRubyWarnings)

unless defined?($SKIP_COVERAGE)
  require 'simplecov'
  SimpleCov.start do
    coverage_dir 'public/coverage'
    add_filter 'config'
    add_filter 'db'
    add_filter 'test'
    add_filter 'vendor'
  end
end

class Object
  def tap_pp(*args)
    pp [*args, self]
    self
  end
end

require_relative '../config/environment'
require 'action_controller/test_case'

class ActiveSupport::TestCase

  def with_login(id)
    Registry.configure do |config|
      config.user_id { id }
    end
    yield id
  ensure
    Registry.configure do |config|
      config.user_id
    end
  end

  def assert_hash(expected, result, so_far=nil)
    diff = expected.keys - result.keys
    assert_equal [], diff.map(&:to_s).sort, "Expected Keys missing#{so_far && " from: #{so_far}"}"

    diff = result.keys - expected.keys
    assert_equal [], diff.map(&:to_s).sort, "Unexpected Keys present#{so_far && " in: #{so_far}"}"

    expected.keys.each do |key|
      if expected[key].is_a?(Hash)
        assert_hash(expected[key], result[key], "#{so_far}#{key}/")
      elsif expected[key] == '__any__'
        assert result.key?(key), "#{so_far}#{key} expected"
      elsif expected[key].is_a?(Regexp) and not result[key].is_a?(Regexp)
        assert_match expected[key], result[key], "#{so_far}#{key} mismatch"
      else
        assert_equal expected[key], result[key], "#{so_far}#{key} mismatch"
      end
    end
  end

end # class ActiveSupport::TestCase