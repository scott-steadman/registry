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

    after_create :notify_create_listeners

    def folder?
      true
    end

  private

    # Issue 2417
    def notify_create_listeners
      return unless parent

      klass = parent.key.classify.constantize rescue return
      return unless klass.respond_to?(:on_create_registry_folder)

      klass.on_create_registry_folder(self)

      return nil
    end

  end # class Folder
end # module Registry
