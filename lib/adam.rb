require 'adam/logging'
require 'adam/client'
require 'adam/amqp_connection'

require 'multi_json'

module Adam

  #Any default configurations go here
  DEFAULTS = {

  }

  def self.options
    #Create a dup, don't take it wholesale
    @options ||= DEFAULTS.dup
  end

  def self.options=(opts)
    @options = opts
  end

  ##
  # Borrowed from Sidekiq, we'll use their configuration model for connecting 
  # to the AMQP server
  # 
  # Adam.configure_server do |config|
  #   config.amqp = { }
  # end  
  #
  # TODO:  Add rack-esque middleware hooks
  #
  def self.configure_server
    yield self if server?
  end

  ##
  # Also borrowed from Sidekiq
  # 
  # Sidekiq.configure_client do |config|
  #   config.amqp = {}
  # end
  #
  #
  def self.configure_client
    yield self unless server?
  end

  def self.server?
    defined?(Adam::CLI)
  end

  def self.load_json(string)
    MultiJson.decode(string)
  end

  def self.logger
    Adam::Logging.logger
  end

  def self.channel(&block)
    raise ArgumentError, "requires a block" if !block
    Adam.conn do |conn|
      @channel ||= AMQP::Channel.new(conn)
      block.call(@channel)
    end    
  end

  def self.conn=(hash)
    if hash.is_a(Hash)
      @conn = Adam::AMQPConnection.create(hash)
    elsif hash.is_a?(ConnectionPool)
      @conn = hash
    else
      raise ArgumentError, "conn= requires a Hash or ConnectionPool"
    end
  end

  def self.conn(&block)
    @conn ||= Adam::AMQPConnection.create
    raise ArgumentError, "requires a block" if !block
    @conn.with(&block)
  end
end