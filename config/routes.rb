Rails.application.routes.draw do
  root :to => 'index#index'

  resources :heartbeat, only: [:index]
  resources :index, path: '/', only: [:index]

  resources :dois, constraints: { :id => /.+/ }

  # rescue routing errors
  match "*path", to: "index#routing_error", via: :all
end
