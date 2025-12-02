module Registry
  class Engine < ::Rails::Engine
    isolate_namespace Registry
    config.autoload_paths << root.join('lib')

    def self.mount_point(route_set=nil)
      return nil unless defined?(Rails) && Rails.application
      @mount_point ||=  begin
        route_set ||= Rails.application.routes
        path        = nil

        route_set.routes.each do |route|
          break if path
          next unless route.app.app.is_a?(Class) && route.app.app < Rails::Engine
          if route.app.app == self
            path = route.path.spec.to_s
          elsif route.app.app.respond_to?(:routes)
            path = mount_point(route.app.app.routes)
          end
        end

        path.gsub(/\([^)]*\)/, '').chomp('/') if path
      end
    end

    #
    # initializer blocks are excecuted during boot (order can vary)
    #
    initializer 'registry.init' do |app|
    end

    #
    # to_prepare blocks are executed after all classes are loaded
    #
    config.to_prepare do
    end

  end # class Engine
end # module Registry
