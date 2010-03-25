require File.dirname(__FILE__) + '/../test_helper'

class OrderTest < Test::Unit::TestCase
  fixtures :orders, :line_items, :products

  def setup
    @order = orders(:first)
  end

  def test_status_description
    @dummy = Order.new
    {"P" => "Pending",
     "C" => "Complete",
     "F" => "Failed",
     "X" => "Cancelled"}.each do |abbrev, description|
      @dummy.status = abbrev
    assert_equal(@dummy.status_description , description)
    end
  end

  def test_create_order_paypal_does_not_validate_anything
    order = Order.new
    order.payment_type = "paypal"
    assert order.save
  end

  def test_create_credit_card_order_validates_name_email_address_and_credit_card_information
    order = Order.new
    order.payment_type = "amex"
    order.first_name = "Steve"
    order.last_name = "Jobs"
    
    order.email = "sjobs@apple.com"
    
    order.address1 = "123 Infinite Loop"
    order.city = "Cupertino"
    order.state = "CA"
    order.zipcode = "12345"
    order.country = "US"
    
    order.cc_number = "1234567890"
    order.cc_month = "12"
    order.cc_year = "2020"
    order.cc_code = "789"
    assert order.save
  end
  
  def test_create_credit_order_checks_first_name
    order = Order.new
    order.payment_type = "amex"
    # order.first_name = "Steve"
    order.last_name = "Jobs"
    
    order.email = "sjobs@apple.com"
    
    order.address1 = "123 Infinite Loop"
    order.city = "Cupertino"
    order.state = "CA"
    order.zipcode = "12345"
    order.country = "US"
    
    order.cc_number = "1234567890"
    order.cc_month = "12"
    order.cc_year = "2020"
    order.cc_code = "789"
    assert_equal false, order.save
  end
  
  def test_create_credit_order_checks_last_name
    order = Order.new
    order.payment_type = "amex"
    order.first_name = "Steve"
    # order.last_name = "Jobs"
    
    order.email = "sjobs@apple.com"
    
    order.address1 = "123 Infinite Loop"
    order.city = "Cupertino"
    order.state = "CA"
    order.zipcode = "12345"
    order.country = "US"
    
    order.cc_number = "1234567890"
    order.cc_month = "12"
    order.cc_year = "2020"
    order.cc_code = "789"
    assert_equal false, order.save
  end

  def test_create_credit_order_checks_email
    order = Order.new
    order.payment_type = "amex"
    order.first_name = "Steve"
    order.last_name = "Jobs"
    
    # order.email = "sjobs@apple.com"
    
    order.address1 = "123 Infinite Loop"
    order.city = "Cupertino"
    order.state = "CA"
    order.zipcode = "12345"
    order.country = "US"
    
    order.cc_number = "1234567890"
    order.cc_month = "12"
    order.cc_year = "2020"
    order.cc_code = "789"
    assert_equal false, order.save
  end
  
  # TODO write tests for checking address and credit card info

  def test_add_form_items
    order = Order.new
    
    product = Product.create(:price => 24.99)
    assert product
    
    items = {
      product.id => 1
    }
    line_item_count = order.line_items.size
    
    assert_equal true, order.add_form_items(items)
        
    assert_equal line_item_count + 1, order.line_items.size
    
    line_item = order.line_items.first
    assert_equal 24.99, line_item.unit_price
    assert_equal 1, line_item.quantity
    assert_equal product.id, line_item.product_id
  end
end
