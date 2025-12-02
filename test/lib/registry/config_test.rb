require 'test_helper'

module Registry
  class ConfigTest < Registry::TestCase

    test 'permission_check' do
      controller = Registry::RegistryController.new

      assert_raises(NoMethodError) do
        controller.permission_check
      end

      Registry.configure do |config|
        config.permission_check { true }
      end

      assert_equal true, controller.permission_check
    end

  end # class ConfigTest
end # module Registry

