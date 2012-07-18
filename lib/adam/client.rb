require 'eventmachine'
require 'amqp'

module Adam
  class Client

    ##
    # Pushes a payload to the AMQP server
    #
    # Example:
    #  Adam::Client.publish('queue' => '', 'class' => MyWorker', 'args' => ['foo', 1, :bat => 'bar'], 'opts' => {:routing_key => "queue_name", :exchange => "fanout"})
    #
    def self.publish(item)
      raise "There needs to be a reactor running to use the ruby-AMQP gem" unless EM.reactor_running?
      worker_class = item['class']
      item['class'] = item['class'].to_s

      Adam.channel do |channel|
        queue    = channel.queue(item['queue'], :auto_delete => false)
        exchange = channel.direct("")
        exchange.publish item['message'], :routing_key => queue.name
      end
    end
  end
end