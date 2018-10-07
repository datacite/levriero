Rails.application.routes.draw do
  root :to => 'index#index'

  resources :heartbeat, only: [:index]
  resources :index, path: '/', only: [:index]

  # trigger agents
  post 'events/import-crossref', :to => 'events#import_crossref'

  # rescue routing errors
  match "*path", to: "index#routing_error", via: :all
end
