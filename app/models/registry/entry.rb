# == Schema Information
#
# Table name: registry_entries
#
#  id          :integer          not null, primary key
#  env         :string(32)
#  parent_id   :integer
#  key         :string(255)
#  type        :string(64)
#  value       :string(255)
#  label       :string(255)
#  description :string(255)
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#  notes       :text
#  version     :integer
#
# Indexes
#
#  index_registry_entries_on_parent_id_and_key  (parent_id,key)
#

module Registry
  class Entry < ApplicationRecord

    self.table_name = 'registry_entries'

    include Versioned
    self.versioned_table_name = 'registry_entry_versions'

    belongs_to :parent,                          :class_name => 'Entry', :foreign_key => 'parent_id'
    has_many   :children, :class_name => 'Entry', :foreign_key => 'parent_id', :dependent => :destroy, :order => 'key asc'

    before_save :ensure_env
    before_save :ensure_type

    # after_update caused intermittent cache clearing
    after_save  :clear_cache

    before_destroy :log_deletion

    ROOT_ACCESS_KEY      = 'root'
    ROOT_LABEL           = 'Configuration Schema'
    DEFAULT_YML_LOCATION = "#{Rails.root}/config/registry.yml"

    # Returns the list of environments defined in the registry
    #
    # call-seq:
    #   Registry::Entry.environments #=> ['development', 'test', 'qa', 'stage', 'production']
    def self.environments
      where('parent_id IS NULL').all.map(&:env).uniq.compact
    end

    # Export the registry to a YAML file and return the hash.
    #
    # ==== Parameters
    #
    # * +file_path+ - Optional path to file.  If nil no file is written.
    #
    # call-seq:
    #   Registry::Entry.export! #=> {'development' => {...}, 'test' => {...}, ...}
    def self.export!(file_path = DEFAULT_YML_LOCATION)
      yaml_data = {}

      environments.each do |env|
        yaml_data[env] = {}
        root(env).export(yaml_data[env])
      end

      if file_path
        File.open(file_path, 'w' ) do |out|
           YAML.dump( yaml_data, out )
        end
      end

      yaml_data
    end

    # Import registry from a YAML file.
    #
    # ==== Parameters
    #
    # * +file_path+ - Path to yml file.
    # * +opts+      - Optional parameters
    #
    # ==== Options
    #
    # * <tt>verbose</tt> - If true, print information to stderr.
    # * merge options (see documentation for <tt>merge</tt> method)
    #
    # ==== File Format
    #
    # yml File should be in the following format:
    #
    # development:
    #   api:
    #     enabled:        true
    #     request_limit:  1
    #
    # test:
    #   api:
    #     enabled:        true
    #     request_limit:  1
    #
    # production:
    #   api:
    #     enabled:        false
    #     request_limit:  1
    #
    #
    # call-seq
    #   Registry::Entry.import!('/path/to/my.yml')
    def self.import!(file_path = DEFAULT_YML_LOCATION, env: Rails.env, verbose: false)
      hash     = YAML.load_file(file_path)
      defaults = hash.fetch(Registry::DEFAULTS_KEY, {})
      STDERR.puts "Importing: #{env}" if verbose
      root(env).merge(defaults.deep_merge(hash[env]), {env: env, verbose: verbose})
    end

    # Return the root entry for an environment.
    #
    # ==== Parameters
    #
    # * +env+ - Optional environment (defaults to Rails.env)
    # * +opts+ - Optional options (defaults to {:auto_create => true})
    #
    # call-seq:
    #   Registry::Entry.root
    def self.root(env=Rails.env)
      ret = where(['parent_id IS NULL AND env = ?', env]).order('id').first
      return ret unless Registry.configuration.auto_create_root
      ret || Folder.create!(:env => env, :key => ROOT_ACCESS_KEY, :label => ROOT_LABEL)
    end

    def key=(new_key)
      write_attribute(:key, new_key.is_a?(String) ? new_key : Transcoder.to_db(new_key))
    end

    def value=(new_value)
      write_attribute(:value, new_value.is_a?(String) ? new_value : Transcoder.to_db(new_value))
    end

    # Return an array ancestor entries.
    def ancestors
      node, nodes = self, []
      nodes << node = node.parent while node.parent
      nodes
    end

    # Return the child entry for a path.
    #
    # ==== Parameters
    #
    # * +path+ - path to child
    #
    # call-seq:
    #   Registry::Entry.root.child('/api/enabled')
    def child(path)
      path.split('/').reject{|ii| ii.blank?}.inject(self) do |parent, key|
        parent.children.find_by_key(key).tap {|ii| raise ArgumentError.new("#{parent.key} has no child named #{key}") if ii.nil?}
      end
    end

    # Return true if the entry is a folder (contains children).
    def folder?
      false
    end

    # Create a property
    #
    # ==== Parameters
    #
    # * +hash+ - Hash of field names and values
    #
    # call-seq:
    #   Registry.entry.root.child('/api').create_property(:key => 'enabled', :value => true)
    def create_property(hash)
      Entry.create!(hash.merge(:parent => self))
    end

    # Return a list of child properties.
    #
    # call-seq:
    #   Registry::Entry.root.child('/api').properties
    def properties
      children.select {|child| not child.folder?}
    end

    # Create and return a folder.
    #
    # ==== Parameters
    #
    # * +hash+ - Hash of field names and values
    #
    # call-seq:
    #   Registry::Entry.root.create_folder(:key => 'api' :label => 'API', :description => 'API Settings')
    def create_folder(hash)
      Folder.create!(hash.merge(:parent => self))
    end

    # Return a list of child folders.
    #
    # call-seq:
    #   Registry::Entry.root.child('/api').folders
    def folders
      children.select {|child| child.folder?}
    end

    # :nodoc:
    def to_folder_hash
      {
        'id'    => id.to_s,
        'key'   => Transcoder.to_db(key),
        'label' => label.to_s,
        'text'  => (label.blank? ? key : label),
        'cls'   => 'folder',
      }
    end

    # :nodoc:
    def to_grid_property_hash
      {
        'id'           => id.to_s,
        'key'          => key,
        'value'        => value,
        'label'        => (label.blank? ? key : label),
        'description'  => description.to_s,
        'access_code'  => access_code,
        'notes'        => notes.to_s,
      }
    end

    # :nodoc:
    def to_form_property_hash
      {
        'key'          => key.to_s,
        'value'        => value.to_s,
        'label'        => label.to_s,
        'description'  => description.to_s,
      }
    end

    # Return a hash containing registry key/value pairs.
    #
    # ==== Parameters
    #
    # * +hash+ - Optional, hash to update.
    #
    # call-seq:
    #   Registry::Entry.root.export #=> {'api' => {'enabled' => true}, '_last_updated_at' => ...}
    def export(hash={}, entries=nil)

      if entries.nil?
        entries = Entry.where(['env = ? and id != ?', env, id])
        hash['_last_updated_at'] = entries.inject(Time.at(0)) {|old_max, entry| [old_max, entry.updated_at].max}
      end

      properties, entries = entries.partition {|entry| entry.parent_id == id && !entry.folder?}
      properties.each do |p|
        hash[Transcoder.from_db(p.key)] = Transcoder.from_db(p.value)
      end

      folders, entries = entries.partition {|entry| entry.parent_id == id && entry.folder?}
      folders.each do |f|
        hash[f.key] ||= {}
        f.export(hash[f.key], entries)
      end

      hash
    end

    # Merge a hash into the current sub-tree.
    #
    # This method will not overwrite key/value pairs already present in leaf nodes.
    #
    # ==== Parameters
    #
    # * +hash+ - hash to merge
    # * +opts+ - Optional merge options
    #
    # ==== Options
    #
    # * <tt>skip_already_deleted</tt> - If true, don't add folders/properties that were previously deleted. (default false)
    # * <tt>delete</tt> - If true, delete entries that are not in +hash+. (default false)
    #
    # call-seq:
    #   Registry::Entry.root.merge({'api' => {'enabled' => true}})
    #   Registry::Entry.root.merge({'api' => {'enabled' => true}}, :skip_already_deleted => true)
    def merge(hash, opts={})
      hash.each do |key, value|
        key = Transcoder.to_db(key)
        reg = Entry.where(['parent_id = ? AND key = ?', self, key]).first
        if value.is_a?(Hash)
          if reg.nil? && should_create?(key, opts)
            puts "Creating folder: #{access_code}.#{key}" if opts[:verbose] # Issue 2
            reg = create_folder(:key => key)
          end
          reg.merge(value, opts) unless reg.nil?
        elsif reg.nil? && should_create?(key, opts)
          puts "Creating property: #{access_code}.#{key} = #{value.inspect}" if opts[:verbose] # Issue 2
          create_property(:key => key, :value => value)
        else
          # don't overwrite
          puts "Skipping existing property: #{access_code}.#{key}" if opts[:verbose] # Issue 2
        end
      end

      if opts[:delete]
        keys = hash.keys.map {|ii| Transcoder.to_db(ii)}
        children.each do |child|
          child.delete unless keys.include?(child.key)
        end
      end
    end

  private

    # Used by UI to get the String containing the ruby code used to access this entry.
    def access_code
      parts = [ 'Registry' ]
      parts << (ancestors.collect{|a| a.key}.reverse - [ROOT_ACCESS_KEY])
      parts.flatten!.compact!
      parts << (([TrueClass, FalseClass].include?(Transcoder.from_db(value).class)) ? "#{key}?" : key)
      parts.join('.')
    end

    def ensure_env
      self.env ||= parent&.env
    end

    # for some reason type doesn't get set for Entry
    def ensure_type
      self.type ||= self.class.name
    end

    def should_create?(key, opts)
      !opts[:skip_already_deleted] || no_prior_deleted_version?(key)
    end

    def no_prior_deleted_version?(key)
      Registry::Entry::Version.where(:parent_id => id, :key => key).none?
    end

    def clear_cache
      Registry.clear_cache(env)
    end

    def log_deletion
      self.notes = '*** entry deleted ***'
      save
    end

  end # class Entry
end # module Registry
