Rails.application.routes.draw do
  namespace :registry do
    root :to => 'registry#index'
    match ':action(/:id)', :controller => 'registry'
  end
end
