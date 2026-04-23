module Registry
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    self.table_name_prefix = 'registry_'
  end
end
