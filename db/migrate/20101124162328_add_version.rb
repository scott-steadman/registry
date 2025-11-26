class AddVersion < ActiveRecord::Migration[8.0]
  def self.up
    add_column :registry_entries, :version, :integer
    Registry::Entry.create_versioned_table
  end

  def self.down
    Registry::Entry.drop_versioned_table
    remove_column :registry_entries, :version
  end
end
