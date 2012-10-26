ExampleStore::Application.routes.draw do
  resources :carts

  resources :line_items

  resources :categories

  resources :orders

  resources :products

  match '/return'=>'carts#return'

  match '/notification' => 'orders#notification'

  match 'orders/:id/refund' => 'orders#refund', :as => 'refund'

  root :to => 'categories#show', :id => 1

end
