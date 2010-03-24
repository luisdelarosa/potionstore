# == Schema Information
#
# Table name: products
#
#  id                 :integer(4)      not null, primary key
#  code               :string(16)      default(""), not null
#  name               :string(64)      default(""), not null
#  price              :decimal(10, 2)  default(0.0), not null
#  image_path         :text
#  url                :text
#  download_url       :text
#  license_url_scheme :text
#  active             :integer(4)      default(1), not null
#

class Product < ActiveRecord::Base
end

