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
      item = worker_class.get_adam_options.merge(item)
      item['retry'] = !!item['retry']

      Adam.channel do |channel|
        @queue    ||= EM::Synchrony::AMQP::Queue.new(channel, item['queue'], :auto_delete => false)
        @exchange ||= EM::Synchrony::AMQP::Exchange.new(channel, :direct, "#{item['queue']}.exchange")
        @queue.bind(@exchange)
        payload = Adam.dump_json(item)
        @exchange.on_return do |basic_return, metadata, return_payload|
          logger.info "#{return_payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
        end
        @exchange.publish(payload)
      end
    end

    def self.enqueue(klass, *args)
      klass.perform_async(*args)
    end
  end
end