class OrdersController < AdminController

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
