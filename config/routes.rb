Rails.application.routes.draw do
  resources :entities, only: :show
  resource :search, only: :show
end
