Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  get '/ping', to: 'pings#ping'

  get '/task1', to: 'tasks#task1'
  get '/task2', to: 'tasks#task2'
end
