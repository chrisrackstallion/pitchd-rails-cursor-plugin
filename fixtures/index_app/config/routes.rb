Rails.application.routes.draw do
  resources :articles, only: %i[ index show edit ]

  resources :cards, only: %i[ show ] do
    resource :closure, only: %i[ create destroy ]
  end
end
