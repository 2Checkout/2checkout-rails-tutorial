Tutorial
=====================

In this tutorial we will walk through integrating the 2Checkout payment method into an existing Rails 3.2.2 shopping cart application using the [twocheckout gem](https://rubygems.org/gems/twocheckout). The source for the example shopping cart application used in this tutorial can be accessed in this [Github repository](https://github.com/2checkout/2checkout-rails-tutorial/ "2checkout-rails-tutorial").

Setting up the Example Application
----------------------------------

We need an existing example application to demonstrate the integration so lets clone the 2checkout-rails-tutorial application.

```shell
$ git clone https://github.com/2checkout/2checkout-rails-tutorial
```

This repository contains both an example before and after application so that we can follow along with the tutorial using the 2checkout-rails-example-before app and compare the result with the 2checkout-rails-example-after app. We can start by navigating to the 2checkout-rails-example-before directory.

```shell
$ cd 2checkout-rails-tutorial/2checkout-rails-example-before
```

From here, we run `bundle install` to install the gems from the Gemfile.

```shell
$ bundle install
```

Lets run the migrations and seed the database.

```shell
$ rake db:migrate
$ rake db:seed
```

Fire up the example application.

```shell
$ rails s
```

View the application in your browser at
[http://localhost:3000](http://localhost:3000)

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/1.png)

As you can see, we have an example shopping cart application that allows you to buy products. There are also a couple additional admin related features that you can access by basic authentication. Lets do this now by accessing [http://localhost:3000/products/](http://localhost:3000/products/). When prompted, enter 'admin' for the username and 'password' for the password. Now you can see menu items to "View/Edit Products" and "View/Edit Orders".

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/2.png)

We can test the current shopping cart functionality of the application by adding a couple of products to the cart.

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/3.png)

The cart calculates the total correctly and lists the appropriate lineitems and quantities, but the buyer cannot pay for their order. We will correct this by adding 2Checkout as a payment method in a few simple steps with the help of the twocheckout gem.

Adding the twocheckout gem
--------------------------

First, lets stop the development server in the terminal `Ctrl + C`. Now we can add the latest version of the twocheckout gem to our Gemfile.

`Gemfile`

```ruby
gem 'twocheckout'
```

Next, we need to install the gem using the `bundle install` command in our terminal.

```shell
$ bundle install
```

Adding 2Checkout as a Payment Method
------------------------------------

The first thing we will do is require the twocheckout gem in our environment.

`config/enviroment.rb`

```ruby
require File.expand_path('../application', __FILE__)

ExampleStore::Application.initialize!
require 'twocheckout'
```

This allows us to use the class methods provided by the twocheckout gem in our application. Now we can add the 2Checkout payment method to our carts view.

`app/views/carts/show.html.erb`

```ruby
<p id="notice"><%= notice %></p>

<h1>Shopping Cart</h1>

<table id="cart" class="table table-striped">
  <tr>
    <th>Product</th>
    <th>Qty</th>
    <th class="price">Unit Price</th>
    <th class="price">Full Price</th>
  </tr>
  <% for line_item in @cart.line_items %>
    <tr class="<%= cycle :odd, :even %>">
      <td><%=h line_item.product.name %></td>
      <td class="qty"><%= line_item.quantity %></td>
      <td class="price"><%= number_to_currency(line_item.unit_price) %></td>
      <td class="price"><%= number_to_currency(line_item.full_price) %></td>
    </tr>
  <% end %>
  <tr>
    <td class="total price" colspan="4">
      Total: <%= number_to_currency @cart.total_price %>
    </td>
  </tr>
</table>
<% @params = {'sid' => 1817037, 'mode' => '2CO', 'merchant_order_id' => @cart.id} %>
<% i=0 %>
<% for line_item in @cart.line_items %>
    <% @params['li_'+i.to_s+'_product_id'] = line_item.product.id.to_s %>
    <% @params['li_'+i.to_s+'_name'] = line_item.product.name %>
    <% @params['li_'+i.to_s+'_price'] = line_item.product.price %>
    <% @params['li_'+i.to_s+'_quantity'] = line_item.quantity.to_s %>
    <% i+=1 %>
<% end %>

<% @form = Twocheckout::Checkout.form(@params, "Pay for your Order") %>
<%= @form.html_safe %>
```

Lets take a second to look at what we did here. The `@params` hash was created with the `sid`_(2Checkout Account Number)_, `mode`_(2Checkout Parameter Set)_ and `merchant_order_id`_(Cart Identifier)_ key-value pairs.

```ruby
<% @params = {
  'sid' => 1817037,
  'mode' => '2CO',
  'merchant_order_id' => @cart.id
} %>
```

Next we loop through the lineitems in our @cart object and add the necessary 2Checkout lineitem parameters to our `@params` hash.

```ruby
<% i=0 %>
<% for line_item in @cart.line_items %>
    <% @params['li_'+i.to_s+'_product_id'] = line_item.product.id.to_s %>
    <% @params['li_'+i.to_s+'_name'] = line_item.product.name %>
    <% @params['li_'+i.to_s+'_price'] = line_item.product.price %>
    <% @params['li_'+i.to_s+'_quantity'] = line_item.quantity.to_s %>
    <% i+=1 %>
<% end %>
```

Now that our hash has all of the 2Checkout sale parameters, we will use the `Twocheckout::Checkout.form()` method to generate our payment form.

```ruby
<% @form = Twocheckout::Checkout.form(@params, "Pay for your Order") %>
<%= @form.html_safe %>
```

Lets test this and make sure we setup everything correctly by loading up our server again and adding some products to our cart.

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/3.png)

We now have a "Pay for your Order" button that when clicked, passes the buyer to 2Checkout to make their payment.

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/4.png)

Adding support for the Passback from 2Checkout
----------------------------------------------

Once the sale is processed successfully, 2Checkout passes the buyer and the sale parameters back to the approved URL that you setup on the Site Management page in your 2Checkout account. We don't have a method yet to handle the passback so lets go ahead and create one in our carts controller.

`app/conrollers/carts_controller.rb`

```ruby
class CartsController < ApplicationController

  def index
    @carts = Cart.all
  end

  def show
    @cart = current_cart
  end

  def new
    @cart = Cart.new
  end

  def edit
    @cart = Cart.find(params[:id])
  end

  def create
    @cart = Cart.new(params[:cart])
  end

  def update
    @cart = Cart.find(params[:id])
  end

  def destroy
    @cart = Cart.find(params[:id])
    @cart.destroy
  end

  def return
    @notification = Twocheckout::ValidateResponse.purchase({:sid => 1817037, :secret => "tango", :order_number => params['order_number'], :total => params['total'], :key => params['key']})

    @cart = Cart.find(params['merchant_order_id'])
    begin
      if @notification[:code] == "PASS"
        @cart.status = 'success'
        @cart.purchased_at = Time.now
        @order = Order.create(:total => params['total'],
          :card_holder_name => params['card_holder_name'],
          :status => 'pending',
          :order_number => params['order_number'])
        reset_session
        flash[:notice] = "Your order was successful! We will contact you directly to confirm before delivery."
        redirect_to root_url
      else
        @cart.status = "failed"
        flash[:notice] = "Error validating order, please contact us for assistance."
        redirect_to root_url
      end
      ensure
      @cart.save
    end
  end
end

```

In our new `return` method we validate the MD5 hash passed back by 2Checkout using the `Twocheckout::ValidateResponse.purchase` method. To use this method, we pass our `sid`_(2Checkout Account Number)_ and `secret`_(2Checkout Secret Word)_ in the `credentials{}` hash as the first argument and pass the `params` as the second argument.

```ruby
  @notification = Twocheckout::ValidateResponse.purchase({:sid => 1817037, :secret => "tango", :order_number => params['order_number'], :total => params['total'], :key => params['key']})
```

We find the buyer's cart using the cart id passed back through the `merchant_order_id` parameter.

```ruby
@cart = Cart.find(params['merchant_order_id'])
```

We then check the response from our `Twocheckout::ValidateResponse.purchase` method. If successful _(MD5 matches)_, the cart status is set to "success", a new order is created and the buyer is redirected to the site with a message indicating that their order went through successfully. If it fails, _(MD5 does not match)_, the cart status is set to "failed" and the buyer is redirected to the site with a message indicating that their order failed.

```ruby
  begin
    if @notification[:code] == "PASS"
      @cart.status = 'success'
      @cart.purchased_at = Time.now
      @order = Order.create(:total => params['total'],
        :card_holder_name => params['card_holder_name'],
        :status => 'pending',
        :order_number => params['order_number'])
      reset_session
      flash[:notice] = "Your order was successful! We will contact you directly to confirm before delivery."
      redirect_to root_url
    else
      @cart.status = "failed"
      flash[:notice] = "Error validating order, please contact us for assistance."
      redirect_to root_url
    end
    ensure
    @cart.save
  end
```

Lets go ahead and create a route for this method.

`config/routes.rb`

```ruby
ExampleStore::Application.routes.draw do
  resources :carts

  resources :line_items

  resources :categories

  resources :orders

  resources :products

  match '/return'=>'carts#return'

  root :to => 'categories#show', :id => 1

end
```

Now that we have our return URL route we need to set the path as your 2Checkout account's approved URL. Lets login to our 2Checkout account and navigate to the Account tab and Site Management subtab.

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/5.png)

From here we can set our new route as the approved URL, select Header Redirect and save the changes.

Lets acid test our application with a live sale!

Start up our server _(If it's not started already.)_

```shell
$ rails s
```

Add some products to our cart and click the **Proceed to Checkout** button and complete the order with 2Checkout.

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/6.png)

We now have our Rails application properly integrated with 2Checkout and can move on to adding additional functionality to check the fraud review result.

INS Notifications
-----------------

2Checkout will send messages on each event that can occur on a sale.

[2Checkout INS Documentation](https://www.2checkout.com/static/va/documentation/INS/index.html)

For this application, we want to know when the sale passes 2Checkout's fraud review, so we will create a new method to handle this message in our orders controller.

`app/conrollers/orders_controller.rb`

```ruby
class OrdersController < AdminController
  skip_filter :authenticate, :only => [:notification]

  def index
    @orders = Order.all
  end

  def show
    @order = Order.find(params[:id])
  end

  def new
    @order = Order.new
  end

  def edit
    @order = Order.find(params[:id])
  end

  def create
    @order = Order.new(params[:total, :card_holder_name, :order_number])
    flash[:notice] = "Order Created Successfully."
  end

  def update
    @order = Order.find(params[:id])
  end

  def destroy
    @order = Order.find(params[:id])
    @order.destroy
    redirect_to orders_path
  end

  def notification
    @notification = Twocheckout::ValidateResponse.notification({:sale_id => params['sale_id'], :vendor_id => 1817037,
      :invoice_id => params['invoice_id'], :secret => "tango", :md5_hash => params['md5_hash']})
    @order = Order.find_by_order_number(params['sale_id'])
    if params['message_type'] == "FRAUD_STATUS_CHANGED"
      begin
        if @notification['code'] == "PASS" and params['fraud_status'] == "pass"
          @order.status = "success"
          render :text =>"Fraud Status Passed"
        else
          @order.status = "failed"
          render :text =>"Fraud Status Failed or MD5 Hash does not match!"
        end
        ensure
        @order.save
      end
    end
  end
end
```

In our new `notification` method we validate the MD5 hash passed back by 2Checkout using the `Twocheckout::Ins.request()` method. To use this method, we pass our `sid`_(2Checkout Account Number)_ and `secret`_(2Checkout Secret Word)_ in the `credentials{}` hash as the first argument and pass the `params` as the second argument. This library returns a JSON response so we will also decode the JSON to a Hash.

```ruby
@notification = Twocheckout::ValidateResponse.notification({:sale_id => params['sale_id'], :vendor_id => 1817037, :invoice_id => params['invoice_id'], :secret => "tango", :md5_hash => params['md5_hash']})
```

We find the buyer's order using the sale number passed back through the `sale_id` parameter.

```ruby
  @order = Order.find_by_order_number(params['sale_id'])
```

We then check the response from our `Twocheckout::Ins.request()` method. If successful _(MD5 matches)_ and the `fraud_status` equals "pass", the order status is set to "success" and for debugging purposes we flash a message indicating that the sale passed fraud review. If it fails, _(MD5 does not match)_, the order status is set to "failed" and we flash a message indicating that the MD5 hash did not match or the sale failed fraud review.

```ruby
  if params['message_type'] == "FRAUD_STATUS_CHANGED"
    begin
      if @notification['code'] == "PASS" and params['fraud_status'] == "pass"
        @order.status = "success"
        render :text =>"Fraud Status Passed"
      else
        @order.status = "failed"
        render :text =>"Fraud Status Failed or MD5 Hash does not match!"
      end
      ensure
      @order.save
    end
  end
```

Lets go ahead and create a route for this method.

`config/routes.rb`

```ruby
ExampleStore::Application.routes.draw do
  resources :carts

  resources :line_items

  resources :categories

  resources :orders

  resources :products

  match '/return'=>'carts#return'

  match '/notification' => 'orders#notification'

  root :to => 'categories#show', :id => 1

end
```

Now we can setup our Notification URL path for the Fraud Status Changed message to "http://localhost:3000/notification" and enable the message under the Notifications page in our 2Checkout admin.

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/7.png)

Lets test our notification function. Now there are a couple ways to go about this. If you are not running the site locally, you can wait for the notifications to come on a live sale. In this tutorial, we are running the site locally so we will use the [INS testing tool](http://developers.2checkout.com/inss) to test the messages. Remember the MD5 hash must match so for easy testing, you must compute the hash based on the like below:

`UPPERCASE(MD5_ENCRYPTED(sale_id + vendor_id + invoice_id + Secret Word))`

You can just use an [online MD5 Hash generator](https://www.google.com/webhp?q=md5+generator) and convert it to uppercase.

Back Office API
---------------

2Checkout's Back Office API provides us with the ability to make calls from our application to preform sale actions, such as stopping a recurring sale or issuing a refund. _(Please visit the [2Checkout API documentation](https://www.2checkout.com/documentation/api/) for instructions on creating an API user)_. For our example application, we will setup the ability to refund a sale from the admin on the orders#show page in case the buyer's order is not in stock.

To accomplish this we will create a new refund method in the orders controller and update the orders/index view to include a refund button for each sale.

`app/conrollers/orders_controller.rb`

```ruby
class OrdersController < AdminController
  skip_filter :authenticate, :only => [:notification]

  def index
    @orders = Order.all
  end

  def show
    @order = Order.find(params[:id])
  end

  def new
    @order = Order.new
  end

  def edit
    @order = Order.find(params[:id])
  end

  def create
    @order = Order.new(params[:total, :card_holder_name, :order_number])
    flash[:notice] = "Order Created Successfully."
  end

  def update
    @order = Order.find(params[:id])
  end

  def destroy
    @order = Order.find(params[:id])
    @order.destroy
    redirect_to orders_path
  end

  def notification
    @notification = Twocheckout::Ins.request({:credentials => {'sid' => '1817037', 'secret' => 'tango'}, :params => params})
    @notification = JSON.parse(@notification)
    @order = Order.find_by_order_number(params['sale_id'])
    if params['message_type'] == "FRAUD_STATUS_CHANGED"
      begin
        if @notification['code'] == "PASS" and params['fraud_status'] == "pass"
          @order.status = "success"
          render :text =>"Fraud Status Passed"
        else
          @order.status = "failed"
          render :text =>"Fraud Status Failed or MD5 Hash does not match!"
        end
        ensure
        @order.save
      end
    end
  end

  def refund
    @order = Order.find(params[:id])
    begin
      Twocheckout::API.credentials = { :username => 'APIuser1817037', :password => 'APIpass1817037' }
      @sale = Twocheckout::Sale.find(:sale_id => @order.order_number)
      @response = @sale.refund!({:comment => "Item(s) not available", :category => 6})
      @order.status = "refunded"
      @order.save
      flash[:notice] = @response[:response_message]
      redirect_to orders_path
    rescue Exception => e
      flash[:notice] = e.message
      redirect_to orders_path
    end
  end
end
```

In our new refund method, we find the order and assign it to a new instance variable.

```ruby
  @order = Order.find(params[:id])
```

We set our 2Checkout API username and password using the `Twocheckout::API.credentials` method. We get the sale object from 2Checkout using the `Twocheckout::Sale.find` method. Then we call the `refund` method on the sale object.

```ruby
Twocheckout::API.credentials = { :username => 'APIuser1817037', :password => 'APIpass1817037' }
@sale = Twocheckout::Sale.find(:sale_id => @order.order_number)
@response = @sale.refund!({:comment => "Item(s) not available", :category => 6})
```

You will notice that we are checking for an exception here as well. 2Checkout will return an exception if the refund cannot be issued on this sale. If the response is successful, we redirect the admin to the orders index page and flash the success response message from 2Checkout's API. If the refund fails, we redirect the admin to the orders index page and flash the error response message from 2Checkout's API.

Let's setup the route for this method.

`config/routes.rb`

```ruby
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
```

Now we can link to this method from the 'orders/index' page.

`app/views/orders/index.html.erb`

```ruby
<p id="notice"><%= notice %></p>

<h1>Orders</h1>
<table class="table table-striped">
  <thead>
    <tr>
      <th>ID</th>
      <th>Customer Name</th>
      <th>Total</th>
      <th>2CO Order Number</th>
      <th>Status</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @orders.each do |order| %>
      <tr>
        <td><%= link_to order.id, order_path(order) %></td>
        <td><%= order.card_holder_name %></td>
        <td><%= order.total %></td>
        <td><%= order.order_number %></td>
        <td><%= order.status %></td>
        <td>
          <%= link_to 'Destroy', order_path(order), :method => :delete, :confirm => 'Are you sure?', :class => 'btn btn-mini btn-danger' %>
          <%= link_to 'Refund', refund_path(order), :confirm => 'Are you sure?', :class => 'btn btn-mini btn-danger' %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

As you can see, all we did here is add the "Refund" button which links to our new `refund_path` route.

```ruby
  <%= link_to 'Refund', refund_path(order), :confirm => 'Are you sure?', :class => 'btn btn-mini btn-danger' %>
```

So now our page has the refund option for each order and when clicked, will return the response from 2Checkout's API.

![](http://github.com/2checkout/2checkout-rails-tutorial/raw/master/img/8.png)

Conclusion
----------
Our application is fully integrated! Buyers can pay for their orders and we register the order in our admin. We update the order based on the Fraud Status Changed INS message, and we provided the site admin with the ability to refund an order using 2Checkout's back office API.

