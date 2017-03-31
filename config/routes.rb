Rails.application.routes.draw do
  devise_for :users
  resources :entities, only: :show do
    resources :relationships, only: :show, path: ''
  end
  resource :search, only: :show
  get 'feedback' => 'pages#feedback'
  root "searches#show"
end
