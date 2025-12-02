class CreateRegistry < ActiveRecord::Migration[8.0]
  def self.up
    create_table :registry_entries do |t|
      t.string  :env,       :null => false, :limit => 32
      t.integer :parent_id

      t.string  :key,       :null => false
      t.text    :type,      :null => false
      t.text    :value

      t.text    :label
      t.text    :description

      t.integer :user_id

      t.timestamps
    end

    add_index :registry_entries, [:parent_id, :key]
  end

  def self.down
    drop_table :registry_entries
  end
end
