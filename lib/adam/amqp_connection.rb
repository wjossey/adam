require 'connection_pool'

module Adam
  class AMQPConnection
    def self.create(options={})
      url = options[:url] || '127.0.0.1'
      # need a connection for Fetcher and Retry
      size = options[:size] || (Adam.server? ? (Adam.options[:concurrency] + 2) : 5)

      ConnectionPool.new(:timeout => 1, :size => size) do
        AMQP.connect(:host => url)
      end
    end
  end
end
