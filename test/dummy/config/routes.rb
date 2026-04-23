Rails.application.routes.draw do
  root to: 'demo#index'

  mount Registry::Engine => "/registry", as: 'registry'
end
