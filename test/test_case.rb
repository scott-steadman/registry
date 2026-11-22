require 'test_helper'

module Registry
  # Helpers shared by the model/library tests (Registry::TestCase) and the
  # controller tests, which have to descend from ActionController::TestCase.
  module TestHelpers
    extend ActiveSupport::Concern

    included do
      # The loaded registry and its cache entry are module-level state that the
      # transaction rollback between tests does not undo, so a test that reads
      # Registry.whatever would otherwise see whatever the last test left there.
      setup do
        Registry.allow_reset!
        Registry.reset(true)
      end
    end

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

  end # module Registry::TestHelpers

  class TestCase < ActiveSupport::TestCase
    include TestHelpers
  end # class Regitry::TestCase
end # module Registry
