require 'connection_pool'

module Adam 
  class AMQPConnection
    SIZE = 1

    def self.create(options={})
      url = options[:url] || '127.0.0.1'
      # need a connection for Fetcher and Retry

      ConnectionPool.new(:timeout => 1, :size => SIZE) do
        connection = EM::Synchrony::AMQP.connect(:host => url)
      end
    end
  end
end
