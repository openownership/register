Rails.application.routes.draw do
  resources :entities, only: :show do
    member do
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
  get 'data-changelog' => 'pages#data_changelog'
  resources :data_sources, only: %i[index show]
  root "pages#home"
end
