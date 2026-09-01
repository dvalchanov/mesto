Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#show"

  get "guides", to: "knowledge#guides", as: :guides
  get "documents", to: "knowledge#documents", as: :documents
  get "glossary", to: "knowledge#glossary", as: :glossary

  resources :property_analyses, only: :create
  get "reports/:public_token", to: "reports#show", as: :report
  post "reports/:public_token/refresh", to: "reports#refresh", as: :refresh_report
  get "reports/:public_token/checkout", to: "orders#new", as: :report_checkout
  post "reports/:public_token/orders", to: "orders#create", as: :report_orders

  get "checkout/:public_token", to: "checkouts#show", as: :checkout
  post "checkout/:public_token/fake/succeed", to: "checkouts#succeed", as: :fake_checkout_succeed
  post "checkout/:public_token/fake/fail", to: "checkouts#fail", as: :fake_checkout_fail
  post "checkout/:public_token/fake/cancel", to: "checkouts#cancel", as: :fake_checkout_cancel
  get "checkout/:public_token/success", to: "checkouts#success", as: :checkout_success
end
