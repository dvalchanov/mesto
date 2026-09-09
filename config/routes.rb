Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.production?
    require "sidekiq/web"

    if Rails.env.production?
      require "rack/auth/basic"

      Sidekiq::Web.use Rack::Auth::Basic, "Mesto Sidekiq" do |username, password|
        Mesto::SidekiqWebAuthentication.valid?(username, password)
      end
    end

    mount Sidekiq::Web => "/sidekiq"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }
  post "product-events", to: "product_events#create", as: :product_events

  # Render the web app manifest from app/views/pwa/manifest.json.erb.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Bulgarian uses the root URLs. English pages use a stable /en prefix so
  # search engines and visitors always receive the same language for a URL.
  scope "(:locale)", locale: /en/ do
    # Defines the root path route ("/")
    root "home#show"

  get "kalkulator", to: "calculators#index", as: :calculators
  get "kalkulator/pokupka-na-imot", to: "calculators#purchase", as: :purchase_calculator
  post "kalkulator/pokupka-na-imot", to: "calculators#calculate_purchase", as: :calculate_purchase_calculator
  get "kalkulator/ipoteka", to: "calculators#mortgage", as: :mortgage_calculator
  post "kalkulator/ipoteka", to: "calculators#calculate_mortgage", as: :calculate_mortgage_calculator
  get "kalkulator/scenarii", to: "budget_scenarios#index", as: :budget_scenarios
  post "kalkulator/scenarii", to: "budget_scenarios#create"
  post "kalkulator/scenarii/sravni", to: "budget_scenarios#compare", as: :compare_budget_scenarios
  get "kalkulator/scenarii/:public_token", to: "budget_scenarios#show", as: :budget_scenario
  patch "kalkulator/scenarii/:public_token", to: "budget_scenarios#update"
  delete "kalkulator/scenarii/:public_token", to: "budget_scenarios#destroy"
  post "kalkulator/scenarii/:public_token/kopie", to: "budget_scenarios#duplicate", as: :duplicate_budget_scenario
  post "kalkulator/scenarii/:public_token/preizchisli", to: "budget_scenarios#recalculate", as: :recalculate_budget_scenario
  post "kalkulator/scenarii/:public_token/zapazi", to: "budget_scenarios#save", as: :save_budget_scenario

  get "guides", to: "knowledge#guides", as: :guides
  get "documents", to: "knowledge#documents", as: :documents
  get "glossary", to: "knowledge#glossary", as: :glossary

  get "narachnik", to: "education#hub", as: :guide
  get "narachnik/pokupka-na-imot", to: "education#buying_overview", as: :buying_guide
  get "narachnik/novo-stroitelstvo", to: "education#building_overview", as: :new_build_guide
  get "narachnik/novo-stroitelstvo/:stage", to: "education#building_stage", as: :new_build_stage
  get "dokumenti", to: "education#documents", as: :education_documents
  get "dokumenti/:slug", to: "education#document", as: :education_document
  get "termini", to: "education#terms", as: :terms
  get "termini/:slug", to: "education#term", as: :term

  get "moeto-mesto", to: "buyer_journeys#show", as: :my_mesto
  post "moeto-mesto", to: "buyer_journeys#create", as: :buyer_journeys
  patch "moeto-mesto", to: "buyer_journeys#update", as: :buyer_journey
  delete "moeto-mesto", to: "buyer_journeys#destroy"
  delete "moeto-mesto/progress", to: "buyer_journeys#reset", as: :reset_buyer_journey
  patch "moeto-mesto/progress", to: "buyer_journeys#update_progress", as: :buyer_journey_progress
  patch "moeto-mesto/select", to: "buyer_journeys#select", as: :select_buyer_journey
  post "reports/:public_token/moeto-mesto", to: "buyer_journeys#attach_analysis", as: :attach_report_to_journey

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
end
