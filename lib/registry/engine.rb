module Registry
  class Engine < ::Rails::Engine
    # Add engine's concerns to autoload paths
    config.autoload_paths << File.expand_path("../../app/models/concerns", __dir__)

    # Load Arel compatibility patches early, before after_initialize
    initializer "registry.load_arel_compat", :before => :load_config_initializers do
      require File.expand_path('../../../lib/extensions/arel_visitor_compat', __FILE__)
    end
  end
end
