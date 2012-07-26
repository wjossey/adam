require 'adam/util'
require 'adam/fiber_pool'

module Adam
  class Manager
    include Util

    def initialize(options={})
      logger.info "Booting adam #{Adam::VERSION} with amqp"
      logger.info "Running in #{RUBY_DESCRIPTION}"
      logger.debug { options.inspect }
      @count = options[:concurrency] || 25
      @queues = options[:queues] || []
      @prefetch = options[:prefetch] || 250
      @done_callback = nil
      @fiber_pool = ::FiberPool.new(options[:concurrency] || SIZE)

      @done = false
      procline
    end

    def run!
      Adam.channel do |channel|
        channel.prefetch(@prefetch)            
        @queues.each do |queue_name|
          #Setup the exchange
          exchange = EM::Synchrony::AMQP::Exchange.new(channel, :direct, "#{queue_name}.exchange")
          #Setup the queue:  Don't auto-delete on consumer disconnect
          queue = AMQP::Queue.new(channel, queue_name, :auto_delete => false)
          queue.bind(exchange)
          #Only delete on ack
          queue.subscribe(:ack => true) do |header, payload|
            msg = Adam.load_json(payload)
            assign(header, msg)            
          end
        end
      end
    end

    def when_done(&blk)
      @done_callback = blk
    end

    def assign(header, msg)
      klass = constantize(msg['class'])
      worker = klass.new
      call_perform = lambda do
        begin 
          worker.perform(*msg['args'])
          header.ack
        rescue Exception => e
          #Still ack, but eventually we'll want retry capability
          logger.info e.message
          logger.info e.backtrace
          header.ack
        end
      end
      @fiber_pool.spawn(&call_perform)              
    end

    private

    def procline
      EventMachine::add_periodic_timer( 5 ) do
        logger.info "adam #{Adam::VERSION} [#{@fiber_pool.busy} of #{@count} busy]"
      end
    end
  end
end