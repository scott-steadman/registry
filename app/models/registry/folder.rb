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

  private

    after_create :notify_create_listeners

    def notify_create_listeners
      return unless parent

      klass = parent.key.classify.constantize rescue return
      return unless klass.respond_to?(:on_create_registry_folder)

      klass.on_create_registry_folder(self)

      nil
    end

    after_create :populate_from_parent_template

    def populate_from_parent_template
      return unless parent.try(:children)

      template = parent.children.select {|folder| folder.key == '_template'}.first
      return unless template

      merge(template.export.except('_last_updated_at'))
      Registry.reset

      nil
    end

  end # class Folder
end # module Registry
