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
  class Folder < Registry::Entry

    def folder?
      true
    end

  end # class Folder
end # module Registry
