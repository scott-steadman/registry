if defined?(NextRails) && NextRails.next?
  Rails.application.routes.draw do
    namespace :registry do
      root :to => 'registry#index'
      match ':action(/:id)', :controller => 'registry'
    end
  end
else
  ActionController::Routing::Routes.draw do |map|
    map.namespace('registry') do |registry|
      registry.root :controller => 'registry'
      registry.connect ':action/:id', :controller => 'registry'
    end
  end
end
