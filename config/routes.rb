Rails.application.routes.draw do
  devise_for :users
  resources :entities, only: :show do
    member do
      get 'tree'
    end
    resources :relationships, only: :show, path: ''
  end
  resource :search, only: :show
  get 'feedback' => 'pages#feedback'
  get 'terms-and-conditions' => 'pages#terms_and_conditions'
  get 'privacy' => 'pages#privacy'
  resources :submissions, only: [:index, :create, :show, :edit], controller: 'submissions/submissions' do
    member do
      post :submit
    end
    resources :entities, only: [:new, :create, :edit, :update, :destroy], controller: 'submissions/entities' do
      collection do
        get :choose
        get :search
      end
      member do
        post :use
        get :remove
      end
    end
    resources :relationships, only: [:edit, :update], controller: 'submissions/relationships'
  end
  root "searches#show"
end
