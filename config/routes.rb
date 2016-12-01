Rails.application.routes.draw do
  resources :entities, only: :show
end
