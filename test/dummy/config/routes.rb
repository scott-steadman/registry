Rails.application.routes.draw do
  mount Registry::Engine => "/registry"
end
