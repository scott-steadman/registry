require 'test_helper'

module Registry
  class WrapperTest < TestCase

    def setup
      Registry::Entry.delete_all # for some reason transactions are not working here
    end

    test 'wrapper decodes string values' do
      wrapper = Registry::Wrapper.new({one: '1'})
      assert_equal 1, wrapper.one
    end

    test 'merge' do
      wrapper  = Registry::Wrapper.new({one: '1'})
      expected = {one: 1, 'two' => 2}

      # 3 = root Folder + two Entries
      assert_difference 'Registry::Entry.count', 3 do
        wrapper.merge(expected)
      end

      assert_equal expected, wrapper.to_hash.except('_last_updated_at')
    end

    test 'ensure_folder_exists creates a missing folder' do
      wrapper = Registry::Wrapper.new({'one' => '1'})

      # 2 = the root Folder (created on first access) + the new one
      assert_difference 'Registry::Folder.count', 2 do
        assert_equal true, wrapper.ensure_folder_exists('two', label: 'Two')
      end

      folder = Registry::Entry.root.child('two')
      assert_equal 'Two', folder.label
      assert_equal true,  folder.is_a?(Registry::Folder)
    end

    test 'ensure_folder_exists leaves an existing key alone' do
      wrapper = Registry::Wrapper.new({'one' => '1'})

      assert_no_difference 'Registry::Entry.count' do
        assert_nil wrapper.ensure_folder_exists('one')
      end
    end

  end # class WrapperTest
end # module Registry

