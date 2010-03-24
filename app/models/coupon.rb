# == Schema Information
#
# Table name: coupons
#
#  id            :integer(4)      not null, primary key
#  code          :string(16)      default(""), not null
#  description   :string(64)      default(""), not null
#  coupon        :string(64)      default(""), not null
#  product_code  :string(16)      default(""), not null
#  amount        :decimal(10, 2)  default(0.0), not null
#  percentage    :integer(4)
#  used_count    :integer(4)
#  use_limit     :integer(4)      default(1), not null
#  creation_time :datetime
#  numdays       :integer(4)      default(0), not null
#

class Coupon < ActiveRecord::Base
  def initialize
    super()
    self.coupon = random_string_of_length(16).upcase
    self.used_count = 0
    self.use_limit = 1
  end

  def expired?
    (self.used_count >= self.use_limit) || (self.numdays != 0 && self.creation_time + self.numdays.days < Time.now)
  end

  private
  def random_string_of_length(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    s = ""
    1.upto(len) { |i| s << chars[rand(chars.size-1)] }
    return s
  end

end

