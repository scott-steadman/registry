require 'test_helper'

module Registry
  class FolderTest < ActiveRecord::TestCase

    class DummyListener
      cattr_accessor :folder
      def self.on_create_registry_folder(folder)
        self.folder = folder
      end
    end

    test 'notify_create_listeners' do
      DummyListener.folder = nil
      parent = Registry::Folder.create!(:env => 'test', :key => 'Registry::FolderTest::DummyListener')
      folder = Registry::Folder.create!(:env => 'test', :key => 'child_folder', :parent => parent)

      assert_equal folder, DummyListener.folder
    end

    test 'populate_from_parent_template' do
      expected = {'name' => 'example name', 'host' => 'example host'}
      parent   = Folder.create!(:env => 'test')
      parent.merge('template_test' => {'_template' => expected})

      parent.child('template_test').merge('test' => {})

      result = parent.child('template_test/test').export.except('_last_updated_at')
      assert_equal expected, result
    end

  end # class FolderTest
end # module Registry