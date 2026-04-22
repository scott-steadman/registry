module Registry
  class Engine < ::Rails::Engine
    # Load Arel compatibility patches early, before after_initialize
    initializer "registry.load_arel_compat", :before => :load_config_initializers do
      require File.expand_path('../../../lib/extensions/arel_visitor_compat', __FILE__)
    end
  end
end
