# Cribbed from acts_as_versioned plugin to be a model concern

module Versioned
  extend ActiveSupport::Concern

  CALLBACKS = [:set_new_version, :save_version, :save_version?]

  included do
    class_attribute :versioned_foreign_key, :versioned_table_name, :versioned_inheritance_column,
      :max_version_limit, :track_altered_attributes, :version_condition, :version_sequence_name, :non_versioned_columns,
      :version_association_options, :version_if_changed

    self.versioned_foreign_key        = self.to_s.foreign_key
    self.versioned_table_name         = "#{table_name_prefix}#{base_class.name.demodulize.underscore}_versions#{table_name_suffix}"
    self.versioned_inheritance_column = "versioned_#{inheritance_column}"
    self.max_version_limit            = 0 # no limit
    self.version_condition            = true
    self.non_versioned_columns        = [self.primary_key, inheritance_column, 'version', 'lock_version', versioned_inheritance_column, 'created_at', 'created_on']

    ensure_versioned_model

    has_many :versions,
             :class_name  => "#{self.to_s}::Version",
             :foreign_key => versioned_foreign_key,
             :order => "version ASC" do

      # finds earliest version of this record
      def earliest
        @earliest ||= first
      end

      # find latest version of this record
      def latest
        @latest ||= order('version desc').first
      end
    end

    before_save  :set_new_version
    after_save   :save_version
    after_save   :clear_old_versions

  end # included

  # Saves a version of the model in the versioned table.  This is called in the after_save callback by default
  def save_version
    return unless defined?(@saving_version) && @saving_version

    @saving_version = nil
    rev = self.class.versioned_class.new
    clone_versioned_model(self, rev)
    rev.version = version
    rev.send("#{self.class.versioned_foreign_key}=", id)
    rev.save!
  end

  # Clears old revisions if a limit is set with the :limit option in <tt>acts_as_versioned</tt>.
  # Override this method to set your own criteria for clearing old versions.
  def clear_old_versions
    return if self.class.max_version_limit == 0
    excess_baggage = version.to_i - self.class.max_version_limit
    if excess_baggage > 0
      self.class.versioned_class.where(["version <= ? and #{self.class.versioned_foreign_key} = ?", excess_baggage, id]).delete_all
    end
  end

  # Reverts a model to a given version.  Takes either a version number or an instance of the versioned model
  def revert_to(version)
    if version.is_a?(self.class.versioned_class)
      return false unless version.send(self.class.versioned_foreign_key) == id and !version.new_record?
    else
      return false unless version = versions.find_by_version(version)
    end
    self.clone_versioned_model(version, self)
    send("version=", version.version)
    true
  end

  # Reverts a model to a given version and saves the model.
  # Takes either a version number or an instance of the versioned model
  def revert_to!(version)
    revert_to(version) ? save_without_revision : false
  end

  # Temporarily turns off Optimistic Locking while saving. Used when reverting so that a new version is not created.
  def save_without_revision
    save_without_revision!
    true
  rescue
    false
  end

  def save_without_revision!
    without_locking do
      without_revision do
        save!
      end
    end
  end

  def altered?
    track_altered_attributes ? (version_if_changed - changed).length < version_if_changed.length : changed?
  end

  # Clones a model.  Used when saving a new version or reverting a model's version.
  def clone_versioned_model(orig_model, new_model)
    self.class.versioned_columns.each do |col|
      new_model.send("#{col.name}=", orig_model.send(col.name)) if orig_model.has_attribute?(col.name)
    end

    if orig_model.is_a?(self.class.versioned_class)
      new_model[new_model.class.inheritance_column] = orig_model[self.class.versioned_inheritance_column]
    elsif new_model.is_a?(self.class.versioned_class)
      new_model[self.class.versioned_inheritance_column] = orig_model[orig_model.class.inheritance_column]
    end
  end

  # Checks whether a new version shall be saved or not.  Calls <tt>version_condition_met?</tt> and <tt>changed?</tt>.
  def save_version?
    version_condition_met? && altered?
  end

  # Checks condition set in the :if option to check whether a revision should be created or not.  Override this for
  # custom version condition checking.
  def version_condition_met?
    case
    when version_condition.is_a?(Symbol)
      send(version_condition)
    when version_condition.respond_to?(:call) && (version_condition.arity == 1 || version_condition.arity == -1)
      version_condition.call(self)
    else
      version_condition
    end
  end

  # Executes the block with the versioning callbacks disabled.
  #
  #   @foo.without_revision do
  #     @foo.save
  #   end
  #
  def without_revision(&block)
    self.class.without_revision(&block)
  end

  # Turns off optimistic locking for the duration of the block
  #
  #   @foo.without_locking do
  #     @foo.save
  #   end
  #
  def without_locking(&block)
    self.class.without_locking(&block)
  end

  def empty_callback() end #:nodoc:

protected

  # sets the new version before saving, unless you're using optimistic locking.  In that case, let it take care of the version.
  def set_new_version
    @saving_version = new_record? || save_version?
    self.version = next_version if new_record? || (!locking_enabled? && save_version?)
  end

  # Gets the next available version for the current record, or 1 for a new record
  def next_version
    (new_record? ? 0 : versions.maximum('version').to_i) + 1
  end

  module ClassMethods
    # Returns an array of columns that are versioned.  See non_versioned_columns
    def versioned_columns
      @versioned_columns ||= columns.select { |c| !non_versioned_columns.include?(c.name) }
    end

    # Returns an instance of the dynamic versioned model
    def versioned_class
      const_get 'Version'
    end

    # Rake migration task to create the versioned table using options passed to acts_as_versioned
    def create_versioned_table(create_table_options = {})
      # create version column in main table if it does not exist
      if !self.content_columns.find { |c| ['version', 'lock_version'].include? c.name }
        self.connection.add_column table_name, 'version', :integer
        self.reset_column_information
      end

      return if connection.table_exists?(versioned_table_name)

      self.connection.create_table(versioned_table_name, **create_table_options) do |t|
        t.column versioned_foreign_key, :integer
        t.column 'version', :integer
      end

      self.versioned_columns.each do |col|
        self.connection.add_column versioned_table_name, col.name, col.type,
          :limit     => col.limit,
          :default   => col.default,
          :scale     => col.scale,
          :precision => col.precision
      end

      if type_col = self.columns_hash[inheritance_column]
        self.connection.add_column versioned_table_name, versioned_inheritance_column, type_col.type,
          :limit     => type_col.limit,
          :default   => type_col.default,
          :scale     => type_col.scale,
          :precision => type_col.precision
      end

      self.connection.add_index versioned_table_name, versioned_foreign_key
    end

    # Rake migration task to drop the versioned table
    def drop_versioned_table
      self.connection.drop_table versioned_table_name
    end

    # Executes the block with the versioning callbacks disabled.
    #
    #   Foo.without_revision do
    #     @foo.save
    #   end
    #
    def without_revision(&block)
      class_eval do
        CALLBACKS.each do |attr_name|
          alias_method "orig_#{attr_name}".to_sym, attr_name
          alias_method attr_name, :empty_callback
        end
      end
      block.call
    ensure
      class_eval do
        CALLBACKS.each do |attr_name|
          alias_method attr_name, "orig_#{attr_name}".to_sym
        end
      end
    end

    # Turns off optimistic locking for the duration of the block
    #
    #   Foo.without_locking do
    #     @foo.save
    #   end
    #
    def without_locking(&block)
      current = ActiveRecord::Base.lock_optimistically
      ActiveRecord::Base.lock_optimistically = false if current
      result = block.call
      ActiveRecord::Base.lock_optimistically = true if current
      result
    end

    def ensure_versioned_model
      return if base_class.const_defined?('Version')

      # create the dynamic versioned model
      base_class.const_set('Version', Class.new(Registry::ApplicationRecord)).class_eval do
        def self.reloadable? ; false ; end

        # find first version before the given version
        def self.before(version)
          where(["#{original_class.versioned_foreign_key} = ? and version < ?", version.send(original_class.versioned_foreign_key), version.version]).order('version desc').first
        end

        # find first version after the given version.
        def self.after(version)
          where(["#{original_class.versioned_foreign_key} = ? and version > ?", version.send(original_class.versioned_foreign_key), version.version]).order('version').first
        end

        def previous
          self.class.before(self)
        end

        def next
          self.class.after(self)
        end

      end # const_set

      versioned_class.class_attribute :original_class
      versioned_class.original_class = base_class
      versioned_class.table_name = versioned_table_name
      versioned_class.belongs_to base_class.to_s.demodulize.underscore.to_sym,
        :class_name  => "::#{base_class.to_s}",
        :foreign_key => versioned_foreign_key
      versioned_class.set_sequence_name version_sequence_name if version_sequence_name

    end #  ensure_versioned_model

  end # module ClassMethods
end # module Versioned