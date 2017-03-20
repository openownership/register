Rails.application.routes.draw do
  devise_for :users
  root "searches#show"
  resources :entities, only: :show do
    resources :relationships, only: :show, path: ''
  end
  resource :search, only: :show
end
