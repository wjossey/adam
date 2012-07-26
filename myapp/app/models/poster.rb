require 'adam'

class Poster# < ActiveRecord::Base
  include Adam::Worker
  adam_options :queue => 'amqp.demo.poster_queue'

  def perform(args)
    EM::Synchrony.sleep(0.05)
  end
end
