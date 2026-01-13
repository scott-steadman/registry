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
      expected = {:one => 1, 'two' => 2}

      # 3 = root Folder + two Entries
      assert_difference 'Registry::Entry.count', 3 do
        wrapper.merge(expected)
      end

      assert_equal expected, wrapper.to_hash.except('_last_updated_at')
    end

  end # class WrapperTest
end # module Registry

