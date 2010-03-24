# == Schema Information
#
# Table name: list_subscribers
#
#  id    :integer(4)      not null, primary key
#  email :text            default(""), not null
#

class ListSubscriber < ActiveRecord::Base
end

