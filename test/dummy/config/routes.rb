Rails.application.routes.draw do
  mount Registry::Engine => "/registry"
  get '/', :to => 'dumy#index'
end
