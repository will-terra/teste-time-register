Rails.application.routes.draw do
   namespace :api do
    namespace :v1 do
      resources :users do
        get 'time_registers', to: 'users#time_registers'
        post 'reports', to: 'users#reports'
      end
      resources :time_registers
      
      # Rotas para gerenciamento de relatórios
      resources :reports, param: :process_id, only: [] do
        member do
          get 'status', to: 'reports#status'
          get 'download', to: 'reports#download'
        end
      end
    end
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
