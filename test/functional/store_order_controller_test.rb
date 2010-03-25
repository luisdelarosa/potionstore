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
    
    product = Product.create(:price => 24.99)
    assert product
    # This will create one new order with one new line item.
    assert_difference ["Order.count", "LineItem.count"] do
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
      
      },
      "items" => {
        product.id => 1
      },
      # It is weird that we have to send address1 again here.
      "address1" => "123 Infinite Loop"
    end    
    
    assert_redirected_to :action => :thankyou
  end
  
  def test_purchase_adds_as_many_line_items_as_there_are_line_items_from_form_even_if_user_buys_multiple_copies_of_same_product
    # Stub out PayPal so we don't call it during testing.
    Order.any_instance.stubs(:paypal_directcharge).returns(true)
    
    product1 = Product.create(:price => 24.99)
    product2 = Product.create(:price => 14.99)
    
    # This will create one new order with one new line item.
    assert_difference "Order.count", 1 do
      assert_difference "LineItem.count", 2 do
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
      
        },
        "items" => {
          product1.id => 1,
          product2.id => 3
        },
        # It is weird that we have to send address1 again here.
        "address1" => "123 Infinite Loop"
      end
    end    
    
    assert_redirected_to :action => :thankyou
  end

end
