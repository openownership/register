Rails.application.routes.draw do
  devise_for :users
  resources :entities, only: :show do
    member do
      get 'tree'
      get 'graph'
      get 'raw'
      get 'opencorporates-additional-info'
    end
    resources :relationships, only: :show, path: ''
  end
  resource :search, only: :show
  get 'terms-and-conditions' => 'pages#terms_and_conditions'
  get 'privacy' => 'pages#privacy'
  get 'faq' => 'pages#faq'
  get 'glossary' => 'pages#glossary'
  get 'download' => 'pages#download'
  resources :submissions, only: %i[index create show edit], controller: 'submissions/submissions' do
    member do
      post :submit
    end
    resources :entities, only: %i[new create edit update destroy], controller: 'submissions/entities' do
      collection do
        get :choose
        get :search
      end
      member do
        post :use
        get :remove
      end
    end
    resources :relationships, only: %i[edit update], controller: 'submissions/relationships'
  end
  namespace :admin do
    resources :submissions, only: %i[index show] do
      member do
        post :approve
      end
    end

    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      expected_username, expected_password = ENV.fetch('ADMIN_BASIC_AUTH').split(':')
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(expected_username)) &
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(expected_password))
    end

    root to: redirect('admin/submissions')
  end
  resources :data_sources, only: :show
  root "searches#show"
end
