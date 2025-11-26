class AddNotesToEntries < ActiveRecord::Migration[8.0]
  def self.up
    add_column :registry_entries, :notes, :text
  end

  def self.down
    remove_column :registry_entries, :notes
  end
end
