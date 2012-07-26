require 'adam'

class Post# < ActiveRecord::Base
  include Adam::Worker
  adam_options :queue => 'amqp.demo.example_queue'

  def perform(args)
    EM::Synchrony.sleep(0.05)
  end
end
