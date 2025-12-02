Registry::Engine.routes.draw do

  get 'index',    :to => 'registry#index'
  get 'viewport', :to => 'registry#viewport'

  get '/', :to => 'registry#index'
end
