require 'connection_pool'

module Adam 
  class AMQPConnection
    SIZE = 1

    def self.create(options={})
      connect_opts = {
        :host => options[:url] || '127.0.0.1',
        :port => options[:port] || 5672,
        :user => options[:user] || 'guest',
        :pass => options[:pass] || 'guest',
        :vhost => options[:vhost] || '/',
        :ssl => options[:ssl] || false,
        :frame_max => options[:frame_max] || 131072
      }
      # need a connection for Fetcher and Retry
      ConnectionPool.new(:timeout => 1, :size => SIZE) do
        EM::Synchrony::AMQP.connect(connect_opts)
      end
    end
  end
end
