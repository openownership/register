# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'pages#home'

  resources :data_sources, only: %i[index show]

  resources :entities, only: :show do
    resources :relationships, only: :show, path: ''
    member do
      get 'graph'
      get 'opencorporates-additional-info'
      get 'raw'
    end
  end

  resource :search, only: :show

  get 'data-changelog',       to: 'pages#data_changelog'
  get 'download',             to: 'pages#download'
  get 'download/latest',      to: 'pages#download_latest'
  get 'faq',                  to: 'pages#faq'
  get 'glossary',             to: 'pages#glossary'
  get 'privacy',              to: 'pages#privacy'
  get 'terms-and-conditions', to: 'pages#terms_and_conditions'
end
