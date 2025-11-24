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

  end # class FolderTest
end # module Registry