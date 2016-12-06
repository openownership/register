Rails.application.routes.draw do
  root "searches#show"
  resources :entities, only: :show
  resource :search, only: :show
end
