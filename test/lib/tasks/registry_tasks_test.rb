require 'test_helper'
require 'rake'

module Registry
  class RegistryTasksTest < TestCase

    def setup
      @original_argv = ARGV.dup

      Rake.application = Rake::Application.new
      Rake::Task.define_task(:environment) # the tasks depend on it; the env is already loaded
      load Registry::Engine.root.join('lib/tasks/registry_tasks.rake')

      @root = Entry.root
      @root.create_folder(:key => 'api').create_property(:key => 'enabled', :value => 'false')
    end

    def teardown
      ARGV.replace(@original_argv)
      Rake.application = nil
    end

    test 'registry:set' do
      # The task reads its arguments off ARGV, dropping the task name itself.
      ARGV.replace(['registry:set', 'api.enabled=true'])

      Rake::Task['registry:set'].invoke

      assert_equal 'true', @root.child('api/enabled').value
    end

    test 'registry:set several values at once' do
      @root.create_property(:key => 'top', :value => 'old')
      ARGV.replace(['registry:set', 'api.enabled=true', 'top=new'])

      Rake::Task['registry:set'].invoke

      assert_equal 'true', @root.child('api/enabled').value
      assert_equal 'new',  @root.child('top').value
    end

    test 'registry:set records a version' do
      ARGV.replace(['registry:set', 'api.enabled=true'])

      assert_difference 'Registry::Entry::Version.count', 1 do
        Rake::Task['registry:set'].invoke
      end
    end

    test 'registry:set with an unknown key' do
      ARGV.replace(['registry:set', 'api.nope=true'])

      assert_raises(ArgumentError) do
        Rake::Task['registry:set'].invoke
      end
    end

  end # class RegistryTasksTest
end # module Registry
