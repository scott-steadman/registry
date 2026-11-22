require 'test_helper'

# Registry::Entry is the only model in the engine that includes Versioned, so it
# stands in for "a versioned model" here.  Registry::EntryTest covers what the
# entries themselves do with their versions; this covers the concern's own API.
class VersionedTest < Registry::TestCase

  # Throwaway model used by the create_versioned_table tests, so they don't have
  # to work around registry_entry_versions already existing.
  WIDGETS_TABLE = 'versioned_widgets'

  def setup
    @root  = Registry::Entry.root
    @entry = @root.create_property(:key => 'one', :value => '1')
  end

  def teardown
    connection.drop_table(WIDGETS_TABLE, :if_exists => true)
    connection.drop_table("#{WIDGETS_TABLE.singularize}_versions", :if_exists => true)
  end

  test 'versions are recorded in order' do
    @entry.update(:value => '2')

    assert_equal [[1, '1'], [2, '2']], @entry.versions.reload.map {|vv| [vv.version, vv.value]}
  end

  test 'earliest and latest version' do
    @entry.update(:value => '2')
    @entry.update(:value => '3')

    assert_equal '1', @entry.versions.earliest.value
    assert_equal '3', @entry.versions.reload.latest.value
  end

  test 'version before and after' do
    @entry.update(:value => '2')
    @entry.update(:value => '3')

    first, second, third = @entry.versions.reload.to_a

    assert_equal second.id, Registry::Entry::Version.before(third).id
    assert_equal second.id, Registry::Entry::Version.after(first).id
    assert_nil Registry::Entry::Version.before(first)
    assert_nil Registry::Entry::Version.after(third)
  end

  test 'version previous and next' do
    @entry.update(:value => '2')

    first, second = @entry.versions.reload.to_a

    assert_equal first.id, second.previous.id
    assert_equal second.id, first.next.id
    assert_nil first.previous
    assert_nil second.next
  end

  test 'revert_to a version number' do
    @entry.update(:value => '2')

    assert_equal true, @entry.revert_to(1)
    assert_equal '1',  @entry.value
    assert_equal 1,    @entry.version
  end

  test 'revert_to an unknown version number' do
    assert_equal false, @entry.revert_to(42)
    assert_equal '1',   @entry.value
  end

  test 'revert_to a version record' do
    @entry.update(:value => '2')

    assert_equal true, @entry.revert_to(@entry.versions.reload.first)
    assert_equal '1',  @entry.value
  end

  test 'revert_to a version record of another entry' do
    other = @root.create_property(:key => 'two', :value => '2')

    assert_equal false, @entry.revert_to(other.versions.first)
    assert_equal '1',   @entry.value
  end

  test 'revert_to an unsaved version record' do
    assert_equal false, @entry.revert_to(Registry::Entry::Version.new(:entry_id => @entry.id))
  end

  test 'revert_to! saves without adding a version' do
    @entry.update(:value => '2')

    assert_no_difference 'Registry::Entry::Version.count' do
      assert_equal true, @entry.revert_to!(1)
    end

    assert_equal '1', @entry.reload.value
  end

  test 'revert_to! an unknown version number does not save' do
    @entry.update(:value => '2')

    assert_equal false, @entry.revert_to!(42)
    assert_equal '2',   @entry.reload.value
  end

  test 'save_without_revision reports a failed save' do
    # The rescue is the point: whatever goes wrong, the caller gets false.
    @entry.define_singleton_method(:save!) {raise ActiveRecord::RecordNotSaved.new('nope', self)}

    assert_equal false, @entry.save_without_revision
  end

  test 'without_revision does not add a version' do
    assert_no_difference 'Registry::Entry::Version.count' do
      @entry.without_revision do
        @entry.update(:value => '2')
      end
    end

    assert_equal '2', @entry.reload.value
  end

  test 'without_revision restores the callbacks when the block raises' do
    assert_raises(RuntimeError) do
      Registry::Entry.without_revision {raise 'boom'}
    end

    assert_difference 'Registry::Entry::Version.count', 1 do
      @entry.update(:value => '2')
    end
  end

  test 'without_locking restores optimistic locking' do
    assert_equal true, ActiveRecord::Base.lock_optimistically, 'Precondition failed: locking should be on'

    locking_inside = Registry::Entry.without_locking {ActiveRecord::Base.lock_optimistically}

    assert_equal false, locking_inside
    assert_equal true,  ActiveRecord::Base.lock_optimistically
  end

  test 'without_locking restores optimistic locking when the block raises' do
    assert_raises(RuntimeError) do
      Registry::Entry.without_locking {raise 'boom'}
    end

    assert_equal true, ActiveRecord::Base.lock_optimistically
  end

  test 'clear_old_versions keeps max_version_limit versions' do
    with_max_version_limit(1) do
      @entry.update(:value => '2')
      @entry.update(:value => '3')

      assert_equal [3], @entry.versions.reload.map(&:version)
    end
  end

  test 'clear_old_versions is a no-op without a limit' do
    assert_equal 0, Registry::Entry.max_version_limit, 'Precondition failed: there should be no limit'

    @entry.update(:value => '2')

    assert_equal [1, 2], @entry.versions.reload.map(&:version)
  end

  test 'version_condition_met? with a symbol' do
    with_version_condition(:altered?) do
      assert_equal false, @entry.reload.version_condition_met?, 'an unchanged record is not altered'

      @entry.value = '2'
      assert_equal true, @entry.version_condition_met?
    end
  end

  test 'version_condition_met? with a proc' do
    with_version_condition(->(entry) {entry.key == 'one'}) do
      assert_equal true,  @entry.version_condition_met?
      assert_equal false, @root.create_property(:key => 'two', :value => '2').version_condition_met?
    end
  end

  test 'version_condition_met? with a boolean' do
    assert_equal true, Registry::Entry.version_condition, 'Precondition failed: the condition should be true'
    assert_equal true, @entry.version_condition_met?

    with_version_condition(false) do
      assert_equal false, @entry.version_condition_met?
    end
  end

  test 'save_version? combines the condition and altered?' do
    assert_equal false, @entry.reload.save_version?, 'an unchanged entry needs no version'

    @entry.value = '2'
    assert_equal true, @entry.save_version?

    with_version_condition(false) do
      assert_equal false, @entry.save_version?
    end
  end

  test 'altered? tracks only version_if_changed when asked to' do
    Registry::Entry.track_altered_attributes = true
    Registry::Entry.version_if_changed       = ['value']

    assert_equal false, @entry.reload.altered?

    @entry.label = 'untracked'
    assert_equal false, @entry.altered?, 'label is not in version_if_changed'

    @entry.value = '2'
    assert_equal true, @entry.altered?
  ensure
    Registry::Entry.track_altered_attributes = nil
    Registry::Entry.version_if_changed       = nil
  end

  test 'versioned_columns excludes the non versioned ones' do
    names = Registry::Entry.versioned_columns.map(&:name)

    assert_equal [], names & Registry::Entry.non_versioned_columns
    assert_includes names, 'value'
  end

  test 'versioned_class' do
    assert_equal Registry::Entry::Version, Registry::Entry.versioned_class
    assert_equal Registry::Entry,          Registry::Entry::Version.original_class
    assert_equal 'registry_entry_versions', Registry::Entry::Version.table_name
  end

  test 'ensure_versioned_model is idempotent' do
    version_class = Registry::Entry.versioned_class

    Registry::Entry.ensure_versioned_model

    assert_same version_class, Registry::Entry.versioned_class
  end

  test 'create_versioned_table and drop_versioned_table' do
    model = versioned_widget_model
    versions_table = model.versioned_table_name

    assert_equal false, connection.column_exists?(WIDGETS_TABLE, :version),
                 'Precondition failed: the widgets table should have no version column'

    model.create_versioned_table

    assert_equal true, connection.column_exists?(WIDGETS_TABLE, :version),
                 'the versioned model gets a version column'
    assert_equal true, connection.table_exists?(versions_table)

    columns = connection.columns(versions_table).map(&:name)
    assert_includes columns, model.versioned_foreign_key
    assert_includes columns, 'version'
    assert_includes columns, 'name',                                 'versioned columns are copied over'
    assert_includes columns, model.versioned_inheritance_column,     'the inheritance column is copied over'
    assert_equal true, connection.index_exists?(versions_table, model.versioned_foreign_key)

    model.drop_versioned_table

    assert_equal false, connection.table_exists?(versions_table)
  end

  test 'create_versioned_table leaves an existing versions table alone' do
    model = versioned_widget_model
    model.create_versioned_table

    connection.add_column(model.versioned_table_name, :extra, :string)
    model.create_versioned_table

    assert_includes connection.columns(model.versioned_table_name).map(&:name), 'extra',
                    'the second call should not have rebuilt the table'
  end

private

  def connection
    ActiveRecord::Base.connection
  end

  # A model with a type column, so create_versioned_table has both a version
  # column to add and an inheritance column to copy.  It has to be named before
  # Versioned is included, because that is when the concern derives the
  # versioned table name and foreign key from it.
  def versioned_widget_model
    connection.create_table(WIDGETS_TABLE, :force => true) do |tt|
      tt.string :name
      tt.string :type
    end

    self.class.send(:remove_const, :VersionedWidget) if self.class.const_defined?(:VersionedWidget, false)
    model = self.class.const_set(:VersionedWidget, Class.new(Registry::ApplicationRecord))
    model.table_name = WIDGETS_TABLE
    model.include(Versioned)
    model
  end

  def with_max_version_limit(limit)
    original = Registry::Entry.max_version_limit
    Registry::Entry.max_version_limit = limit
    yield
  ensure
    Registry::Entry.max_version_limit = original
  end

  def with_version_condition(condition)
    original = Registry::Entry.version_condition
    Registry::Entry.version_condition = condition
    yield
  ensure
    Registry::Entry.version_condition = original
  end

end # class VersionedTest
