require 'test_helper'

module Registry
  class ConfigTest < Registry::TestCase

    test 'permission_check' do
      config = Registry.configuration
      controller = Registry::RegistryController.new

      assert_raises(NoMethodError, 'Precondition failed: permission_check should be absent') do
        controller.permission_check
      end

      config.permission_check { true }
      assert_equal true, controller.permission_check, 'permission_check should be set'

      config.permission_check
      assert_raises(NoMethodError, 'permission_check should be removed') do
        controller.permission_check
      end
    end

  end # class ConfigTest
end # module Registry

