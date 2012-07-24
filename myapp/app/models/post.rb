require 'adam'

class Post# < ActiveRecord::Base
  include Adam::Worker
  adam_options :queue => 'amqp.demo.example_queue'
  
  def long_method(other_post)
    puts "Running long method with #{self.id} and #{other_post.id}"
  end
end
