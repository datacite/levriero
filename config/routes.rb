Rails.application.routes.draw do
  root to: "index#index"

  resources :heartbeat, only: [:index]
  resources :index, path: "/", only: [:index]

  # trigger agents
  post "agents/crossref", to: "agents#crossref"
  post "agents/crossref-orcid", to: "agents#crossref_orcid"
  post "agents/crossref-funder", to: "agents#crossref_funder"
  post "agents/crossref-related", to: "agents#crossref_related"

  # rescue routing errors
  # match "*path", to: "index#routing_error", via: :all
end
