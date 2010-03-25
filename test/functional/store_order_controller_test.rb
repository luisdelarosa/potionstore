require File.dirname(__FILE__) + '/../test_helper'
require 'store/order_controller'

# Re-raise errors caught by the controller.
class Store::OrderController; def rescue_action(e) raise e end; end

class StoreOrderControllerTest < Test::Unit::TestCase

  def setup
    @controller = Store::OrderController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_get_index
    get :index
    assert_response :success
  end
    
  def test_new_store_order
    get :new
    assert_response :success
    
    # No order ID yet
    assert_nil @response.session[:order_id]
    
    # No quantities yet
    assert_equal Hash.new, assigns(:qty)
    
    # No payment type yet
    assert_nil assigns(:payment_type)
  end
  
  def test_purchase_redirects_to_index_if_no_order_and_no_items
    post :purchase
    assert_redirected_to :action => :index
  end

  def test_purchase_redirects_to_index_if_no_order
    post :purchase, :order => {}
    assert_redirected_to :action => :index
  end

  def test_purchase_redirects_to_index_if_no_items
    post :purchase, :items => {}
    assert_redirected_to :action => :index
  end

  def test_purchase_should_not_redirect_to_index
    # Stub out PayPal so we don't call it during testing.
    Order.any_instance.stubs(:paypal_directcharge).returns(true)
    
    post :purchase, :order => {
      "payment_type" => "amex",
      "first_name" => "Steve",
      "last_name" => "Jobs",
      "licensee_name" => "Steve Jobs", # This concatenation should be moved to the controller method.
      "email" => "sjobs@apple.com",
      "address1" => "123 Infinite Loop",
      "city" => "Cupertino",
      "state" => "CA",
      "zipcode" => "12345",
      "country" => "US",
      "cc_number" => "1234567890",
      "cc_month" => "12",
      "cc_year" => "2020",
      "cc_code" => "789"
      
    }, :items => [],
    # It is weird that we have to send address1 again here.
    "address1" => "123 Infinite Loop"
    
    assert_redirected_to :action => :thankyou
  end

end
