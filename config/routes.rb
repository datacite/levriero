Rails.application.routes.draw do
  resources :metadata
  resources :media
  root :to => 'index#index'

  resources :heartbeat, only: [:index]
  resources :index, path: '/', only: [:index]
  resources :status, only: [:index]

  resources :clients, constraints: { :id => /.+/ }
  resources :providers do
    resources :clients, constraints: { :id => /.+/ }, shallow: true
  end
  resources :providers, constraints: { :id => /.+/ }

  # re3data
  # resources :repositories, only: [:show, :index]
  # get "/repositories/:id/badge", to: "repositories#badge", format: :svg

  # resources :resource_types, path: 'resource-types', only: [:show, :index]

  # support for legacy routes
  resources :members, only: [:show, :index]
  resources :data_centers, only: [:show, :index], constraints: { :id => /.+/ }, path: "/data-centers"
  # resources :works, only: [:show, :index], constraints: { :id => /.+/ }

  # rescue routing errors
  match "*path", to: "index#routing_error", via: :all
end
