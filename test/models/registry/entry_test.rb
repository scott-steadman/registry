require 'test_helper'

module Registry
  class EntryTest < TestCase

    CONFIG = "#{Rails.root}/tmp/registry.yml"

    def setup
      Dir.mkdir("#{Rails.root}/tmp") rescue nil
      File.delete(CONFIG)            rescue nil
    end

    test 'environments' do
      create_entries
      assert_equal ['dev', 'test'], Entry.environments.sort
    end

    test 'export!' do
      expected = create_entries
      assert_hash expected, Entry.export!(CONFIG)
      assert_equal true, File.exist?(CONFIG), 'Export file should be created'
    end

    test 'export! no file' do
      File.delete(Entry::DEFAULT_YML_LOCATION) rescue nil
      expected = create_entries
      assert_hash expected, Entry.export!(nil)
      assert_equal false, File.exist?(Entry::DEFAULT_YML_LOCATION), 'Export file should NOT be created'
    end

    test 'export' do
      expected = create_entries['test']
      assert_hash expected, Entry.root.export
    end

    test 'import does not overwrite' do
      root = Entry.root('dev')
      root.create_property(:key => 'one', :value => 'preserve')
      two = root.create_folder(:key => 'two')
      two.create_property(:key => 'one', :value => 'preserve')

      data = {
        'dev' => {
          'one' => 'new',
          'two' => {'one' => 'new', 'two' => 'new'},
          'tre' => 'new',
        },
      }
      File.open(CONFIG, 'w') do |out|
        YAML.dump(data, out)
      end

      # Issue 2
      Entry.import!(CONFIG, :env => 'dev', :verbose => true)

      expected = {
        'dev' => {
          '_last_updated_at' => '__any__',
          'one'              => 'preserve',
          'two'              => {'one' => 'preserve', 'two' => 'new'},
          'tre'              => 'new',
        }
      }
      assert_hash expected, Entry.export!(nil)
    end

    test 'versioning' do
      prop = Entry.root.create_property(:key => 'one', :value => 'one')

      assert_difference 'Registry::Entry::Version.count', 1 do
        prop.update(:value => 'two')
      end

      prop.revert_to!(1)
      assert_equal 'one', prop.reload.value, 'Reversion failed'

      prop.update(:value => 'three')
      assert_equal 3, prop.reload.version
    end

    # Registry::Entry is always versioned: entry.rb calls ensure_versioned_model in its class
    # body, so Registry::Entry::Version exists from the moment the model is loaded, with nothing
    # having been saved.
    #
    # It is worth asserting because every other versioning test here is blind to it. They all
    # create an entry before updating one, and an insert is the single path that never reads the
    # versions association -- next_version answers 1 for a new record -- so the insert's own
    # after_save would build the class and cover for its being missing. That is how the class came
    # to be built a callback too late and nothing noticed: set_new_version is a before_save and
    # reads versions.maximum('version'), while the only caller of ensure_versioned_model was
    # save_version, an after_save. Any process whose first write was an *update* -- which is most
    # of them, the rows being there already -- could not save a registry entry at all.
    test 'Registry::Entry is always versioned' do
      assert_equal true, Entry.const_defined?(:Version, false),
                   'the versioned class should exist before anything has been saved'
      assert_equal 'registry_entry_versions', Entry::Version.table_name
      assert_equal Entry, Entry::Version.original_class
      assert_nothing_raised { Entry.reflect_on_association(:versions).klass }
    end

    # ...and the same invariant in a process of its own, because the test above can be satisfied by
    # an earlier test in a random order having saved an entry and built the class as a side effect.
    # This is the only assertion here that a lazily-built class cannot pass.
    test 'a fresh process has the versioned class before it saves anything' do
      script = 'require "./test/dummy/config/environment"; ' \
               'exit(Registry::Entry.const_defined?(:Version, false) ? 0 : 1)'

      Dir.chdir(Rails.root.join('..', '..')) do
        assert_equal true, system({'RAILS_ENV' => 'test'}, RbConfig.ruby, '-e', script,
                                  out: File::NULL, err: File::NULL),
                     'Registry::Entry::Version should be defined at load, with no save to build it'
      end
    end

    test 'deletes are versioned' do
      prop = Entry.root.create_property(:key => 'one', :value => 'one')

      assert_difference 'Registry::Entry::Version.count', 1 do
        assert_difference 'Registry::Entry.count', -1 do
          prop.destroy
        end
      end

      version = Registry::Entry::Version.last
      assert_match 'deleted', version.notes
    end

    test 'skip_already_deleted prevents property creation if deleted' do
      Entry.root.create_property(:key => 'one', :value => 'one').destroy

      folder = Entry.root.create_folder(:key => 'folder')
      folder.create_property(:key => 'two', :value => 'two').destroy

      assert_no_difference 'Registry::Entry.count' do
        Entry.root.merge({'one' => 'two'}, :skip_already_deleted => true)
        folder.merge({'two' => 'three'}, :skip_already_deleted => true)
      end
    end

    test 'skip_already_deleted prevents folder creation if deleted' do
      Entry.root.create_folder(:key => 'one').destroy

      folder = Entry.root.create_folder(:key => 'folder')
      folder.create_folder(:key => 'two').destroy

      assert_no_difference 'Registry::Entry.count' do
        Entry.root.merge({'one' => {'one' => 'one'}}, :skip_already_deleted => true)
        Entry.root.merge({'folder' => {'two' => {:one => 'one'}}}, :skip_already_deleted => true)
        folder.merge({'two' => {:one => 'one'}}, :skip_already_deleted => true)
      end
    end

    test 'merge with delete flag' do
      Entry.root.merge(
        'keep' => {:keep => true, :lose => false},
        :keep  => 'keep',
        'lose' => {:lose => true},
        :lose  => 'lose'
      )

      Entry.root.merge({'keep' => {:keep => 'ignored'}, :keep => 'ignored'}, :delete => true)

      expected = {'keep' => {:keep => true}, :keep => 'keep', '_last_updated_at' => '__any__'}
      assert_hash expected, Entry.root.export
    end

    test 'child' do
      create_entries
      assert_equal true, Entry.root.child('folder1').folder?
      assert_equal true, Entry.root.child('/folder1').folder?, 'child method should handle leading /'
      assert_equal ':symbol', Entry.root.child('folder2/:symbol').value
      assert_raise ArgumentError do
        Entry.root.child('foo/bar')
      end
    end

  private

    def create_entries(envs=nil, folders=nil, values=nil)
      envs    ||= ['dev', 'test']
      folders ||= ['folder1', 'folder2']
      values  ||= {
        'string'  => 'string',
        false     => false,
        42        => -42,
        3.14      => -3.14,
        :symbol   => :symbol,
        'time'    => Time.parse('1968-05-21 12:59:00'),
        1 ... 10  => 1 .. 10,
        'array'   => ['string', false, -42, -3.14, :symbol, Time.parse('1968-05-21 12:59:00'), 1...10]
      }

      entries = {}

      envs.each do |env|
        entries[env] ||= {}
        root = Entry.root(env)

        folders.each do |folder|
          entries[env][folder] ||= {}
          folder = Folder.create!(:parent => root, :key => folder)

          values.each do |key, value|
            Entry.create!(:parent => folder, :key => key, :value => value)
            entries[env][folder.key].store(key, value)
          end
        end

        entries[env]['_last_updated_at'] = '__any__'
      end

      entries
    end

  end # class EntryTest
end # module Registry
