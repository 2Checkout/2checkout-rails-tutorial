ExampleStore::Application.routes.draw do
  resources :carts

  resources :line_items

  resources :categories

  resources :orders

  resources :products

  root :to => 'categories#show', :id => 1

end
