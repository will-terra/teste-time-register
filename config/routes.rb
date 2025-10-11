Rails.application.routes.draw do
  # API routes for version 1
  namespace :api do
    namespace :v1 do
      # User resources with nested routes for time registers and reports
      resources :users do
        # Custom route to get time registers for a user
        get "time_registers", to: "users#time_registers"
        # Custom route to create a report for a user
        post "reports", to: "users#reports"
      end
      # Standard CRUD routes for time registers
      resources :time_registers

      # Routes for report management using process_id as parameter
      resources :reports, param: :process_id, only: [] do
        member do
          # Get the status of a report generation process
          get "status", to: "reports#status"
          # Download the generated report
          get "download", to: "reports#download"
        end
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Health check route for load balancers and uptime monitors
  # Returns 200 if the app boots without exceptions, otherwise 500
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/") - commented out as this is an API-only app
  # root "posts#index"
end
