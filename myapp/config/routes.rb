#require 'sidekiq/web'

Myapp::Application.routes.draw do
  #mount Sidekiq::Web => '/sidekiq'
  #get "work" => "work#index"
  #get "work/email" => "work#email"
  #get "work/post" => "work#delayed_post"
  #get "work/long" => "work#long"
  #get "work/crash" => "work#crash"
end
