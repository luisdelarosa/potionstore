# General flow:
# 1. new
# 2. payment
# 3A. If paypal, then go to PayPal's site
# 3A1. Upon return from PayPal, confirm_paypal
# 3A2. purchase_paypal
# 3A3. finish_order
# 3A4. thank_you
# 3B. Else
# 3B1. purchase
# 3B2A. If credit card, then payment_cc
# 3B2B. If Google Checkout, then payment_gcheckout
# 3B3 - For both credit card and Google checkout, next is purchase
# 3B3A - if credit card, then next is: finish_order and then thank_you
# 3B3B - if Google Checkout, then next is: order.send_to_google_checkout - then it is all at Google's site, I think.

class Store::OrderController < ApplicationController
  layout "store"

  before_filter :redirect_to_ssl

  def index
    new
    render :action => 'new'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def new
    session[:order_id] = nil
    @qty = {}
    @payment_type = session[:payment_type]
    @products = Product.find(:all, :conditions => {:active => 1})
    if params[:product]
      @qty[params[:product]] = 1
    elsif session[:items]
      for key in session[:items].keys
        @qty[Product.find(key).code] = session[:items][key]
      end
    end
  end

  def payment
    session[:order_id] = nil
    redirect_to :action => 'index' and return if !params[:items]
    @order = Order.new
    @order.payment_type = params[:payment_type]
    session[:payment_type] = params[:payment_type]

    session[:items] = params[:items]

    if not @order.add_form_items(params[:items])
      flash[:notice] = 'Nothing to buy!'
      redirect_to :action => 'index' and return
    end

    coupon_text = params[:coupon].strip
    @order.coupon_text = coupon_text

    if !coupon_text.blank? && @order.coupon == nil
      coupon = Coupon.find_by_coupon(coupon_text)
      if coupon != nil && coupon.expired?
        flash[:notice] = 'Coupon Expired'
      else
        flash[:notice] = 'Invalid Coupon'
      end
      session[:coupon_text] = params[:coupon].strip
      redirect_to :action => 'index' and return
    end

    if @order.total <= 0
      flash[:notice] = 'Nothing to buy!'
      redirect_to :action => 'index' and return
    end

    # Handle Paypal orders
    if params[:payment_type] == 'paypal'
      res =  Paypal.express_checkout(:amount => String(@order.total),
                                     :cancelURL => url_for(:action => 'index'),
                                     :returnURL => url_for(:action => 'confirm_paypal'),
                                     :noShipping => 1,
                                     :cpp_header_image => $STORE_PREFS['paypal_express_checkout_header_image'])
      if res.ack == 'Success' || res.ack == 'SuccessWithWarning'
        # Need to copy the string. For some reason, it tries to render the payment action otherwise
        session[:paypal_token] = String.new(res.token)
        if not @order.save()
          flash[:notice] = 'Problem saving order'
          redirect_to :action => 'index' and return
        end
        session[:order_id] = @order.id
        redirect_to Paypal.express_checkout_redirect_url(res.token) and return
      else
        flash[:notice] = 'Could not connect to PayPal'
        redirect_to :action => 'index' and return
      end

    # Handle Google Checkout orders
    elsif params[:payment_type] == 'gcheckout'
      render :action => 'payment_gcheckout' and return
    end

    # credit card order

    # put in a dummy credit card number for testing
    @order.cc_number = '4916306176169494' if not is_live?()

    render :action => 'payment_cc'
  end

  def redirect
    redirect_to :action => 'index'
  end

  # Accept orders from Cocoa storefront. It only works with JSON right now
  def create
    if params[:order] == nil
      respond_to do |format|
        format.json { render :json => '["Did not receive order"]', :status => :unprocessable_entity and return }
      end
    end

    # If there's a completed order in the session, just return that instead of charging twice
    if session[:order_id] != nil
      @order = Order.find(session[:order_id])
      if @order != nil && @order.status == 'C'
        respond_to do |format|
          format.json { render :json => @order.to_json(:include => [:line_items]) }
        end
        return
      end
    end

    @order = Order.new(params[:order])

    session[:order_id] = @order.id

    if not @order.save()
      respond_to do |format|
        format.json { render :json => @order.errors.full_messages.to_json, :status => :unprocessable_entity }
      end
      return
    end

    # Actually send out the payload
    if @order.cc_order?
      success = @order.paypal_directcharge(request)
      @order.status = success ? 'C' : 'F'
      @order.finish_and_save() if success

      respond_to do |format|
        if success
          format.json { render :json => @order.to_json(:include => [:line_items]) }
        else
          format.json { render :json => @order.errors.full_messages.to_json, :status => :unprocessable_entity }
        end
      end
    end
  end

  def purchase
    redirect_to :action => 'index' and return unless params[:order] && params[:items]

    if session[:order_id] != nil
      @order = Order.find(session[:order_id])
      if @order != nil && @order.status == 'C'
        render :action => 'failed', :layout => 'error' and return
      end
    end

    # We need the next two ugly lines because Safari's form autofill sucks
    params[:order][:address1] = params[:address1]
    params[:order][:address2] = params[:address2]

    params[:order].keys.each { |x| params[:order][x] = params[:order][x].strip if params[:order][x] != nil }

    @order = Order.new(params[:order])

    # the order in the session is a bogus temporary one
    @order.add_form_items(params[:items])

    if params[:coupon]
      @order.coupon_text = params[:coupon]
    end

    @order.order_time = Time.now()
    @order.status = 'S'
    session[:order_id] = @order.id
    session[:items] = nil

    if not @order.save()
      flash[:error] = 'Please fill out all fields'
      if @order.cc_order?
        render :action => 'payment_cc' and return
      else
        render :action => 'payment_gcheckout' and return
      end
    end

    # Actually send out the payload
    if @order.cc_order?
      success = @order.paypal_directcharge(request)
      finish_order(success)
    else
      # Google Checkout order
      redirect_url = @order.send_to_google_checkout(url_for(:action => 'index'))
      if redirect_url == nil
        @order.failure_reason = 'Could not connect to Google Checkout'
        render :action => 'failed', :layout => 'error' and return
      end
      redirect_to redirect_url and return
    end
  end

  # This is the main re-entry point from the PayPal checkout workflow, after returning from PayPal's site.
  def confirm_paypal
    render :action => 'no_order', :layout => 'error' and return if session[:order_id] == nil

    @order = Order.find(session[:order_id])
    redirect_to :action => 'index' and return if @order == nil || session[:paypal_token] != params[:token]

    # Suck the info from PayPal
    res = Paypal.express_checkout_details(:token => session[:paypal_token])

    if res.ack != 'Success' && res.ack != 'SuccessWithWarning'
      flash[:notice] = 'Could not retrieve order information from PayPal'
      redirect_to :action => 'index' and return
    end

    payerInfo = res.getExpressCheckoutDetailsResponseDetails.payerInfo
    session[:paypal_payer_id] = params['PayerID']
    @order.email = String.new(payerInfo.payer)
    @order.first_name = String.new(payerInfo.payerName.firstName)
    @order.last_name = String.new(payerInfo.payerName.lastName)
    @order.licensee_name = @order.first_name + " " + @order.last_name
    if payerInfo.respond_to? 'payerCountry'
      @order.country = String.new(payerInfo.payerCountry)
    else
      @order.country = 'XX'
    end
    @order.payment_type = 'PayPal'

    if not @order.save()
      flash[:error] = 'Problem saving order'
      render :action => 'confirm_paypal' and return
    end

    session[:order_id] = @order.id
  end

  # This is the next step in the PayPal checkout workflow after confirm_paypal.
  def purchase_paypal
    render :action => 'no_order', :layout => 'error' and return if session[:order_id] == nil

    @order = Order.find(session[:order_id])
    @order.attributes = params[:order]

    redirect_to :action => 'index' and return if session[:paypal_token] == nil
    render :action => 'failed', :layout => 'error' and return if !@order.pending?

    @order.order_time = Time.now()
    @order.status = 'S'

    if not @order.save()
      flash[:error] = 'Please fill out all fields'
      render :action => 'confirm_paypal' and return
    end

    success = @order.paypal_express_checkout_payment(session[:paypal_token], session[:paypal_payer_id])

    finish_order(success)
  end

  ## Methods that need a completed order
  before_filter :check_completed_order, :only => [:thankyou, :receipt]

  def thankyou
    # no need to check for nil order in the session here.
    # check_completed_order is a before_filter for this method
    @order = Order.find(session[:order_id])
  end

  def receipt
    # no need to check for nil order in the session here.
    # check_completed_order is a before_filter for this method
    @order = Order.find(session[:order_id])
    @print = true
    render :partial => 'receipt'
  end

  ## Private methods
  private
  def check_completed_order
    @order = Order.find(session[:order_id])
    unless @order && @order.complete?
      redirect_to :action => "index"
    end
  end

  private
  def finish_order(success)
    if params[:subscribe] && params[:subscribe] == 'checked'
      @order.subscribe_to_list()
    end

    @order.status = success ? 'C' : 'F'
    @order.finish_and_save()

    if success
      session[:order_id] = @order.id
      redirect_to :action => 'thankyou'
    else
      render :action => 'failed', :layout => 'error'
    end
  end

end
