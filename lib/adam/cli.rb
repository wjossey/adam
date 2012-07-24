trap 'INT' do
  # Handle Ctrl-C in JRuby like MRI
  # http://jira.codehaus.org/browse/JRUBY-4637
  Adam::CLI.instance.interrupt
end

trap 'TERM' do
  # Heroku sends TERM and then waits 10 seconds for process to exit.
  Adam::CLI.instance.interrupt
end

trap 'USR1' do
  Adam.logger.info "Received USR1, no longer accepting new work"
  mgr = Adam::CLI.instance.manager
  mgr.stop! if mgr
end

trap 'TTIN' do
  Thread.list.each do |thread|
    puts "Thread TID-#{thread.object_id.to_s(36)} #{thread['label']}"
    puts thread.backtrace.join("\n")
  end
end

require 'yaml'
require 'singleton'
require 'optparse'

require 'adam'
require 'adam/util'
require 'em-synchrony'
module Adam
  class CLI
    include Singleton
    include Util

    SIZE = 100

    def initialize 
      @code = nil
      @interrupt_mutex = Mutex.new
      @interrupted = false
      @fiber_pool = ::FiberPool.new(SIZE)
      puts "Fiber pool initialized"
    end

    def parse(args=ARGV)
      @code = nil
      Adam.logger

      cli = parse_options(args)
      config = parse_config(cli)
      options.merge!(config.merge(cli))

      Adam.logger.level = Logger::DEBUG if options[:verbose]

      validate!
      write_pid
      boot_system
    end

    def run
      puts "Omgz we're running"
      EM.synchrony do
        begin 
          connection = AMQP.connect(:host => '127.0.0.1')
          puts "Connected to broker"
          channel = AMQP::Channel.new(connection)
          # exchange = channel.direct("amqp.demo.example_queue1")
          # channel.prefetch(1)
          # queue = channel.queue('amqp.demo.example_queue1')
          # queue.bind(exchange, :routing_key => 'amqp.demo.example_queue1')
          # puts "Subscribing to queue"

          queue    = EM::Synchrony::AMQP::Queue.new(channel, 'amqp.demo.example_queue1', :auto_delete => false)
          exchange = EM::Synchrony::AMQP::Exchange.new(channel, :direct, "amqp.demo.example_queue1.exchange")
          queue.bind(exchange)

          queue.subscribe do |header, payload|
            msg = Adam.load_json(payload)
            klass = constantize(msg['class'])
            worker = klass.new
            worker.perform(*msg['args'])
          end
          puts "Subscribed"
        rescue Interrupt
          logger.info "Shutting down"
          exit(0)
        end
      end
      # @manager = Adam::Manager.new(options)
      # begin
      #   logger.info 'Starting processing, hit Ctrl-C to stop'
      #   @manager.start!
      #   sleep
      # rescue Interrupt
      #   logger.info 'Shutting down'
      #   @manager.stop!(:shutdown => true, :timeout => options[:timeout])
      #   @manager.wait(:shutdown)
      #   # Explicitly exit so busy Processor threads can't block
      #   # process shutdown.
      #   exit(0)
      # end
    end

    def interrupt
      @interrupt_mutex.synchronize do
        unless @interrupted
          @interrupted = true
          EM.stop
          Thread.main.raise Interrupt
        end
      end
    end

    private

    def die(code)
      exit(code)
    end

    def options
      Adam.options
    end

    def detected_environment
      options[:environment] ||= ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def boot_system
      ENV['RACK_ENV'] = ENV['RAILS_ENV'] = detected_environment

      raise ArgumentError, "#{options[:require]} does not exist" unless File.exist?(options[:require])

      if File.directory?(options[:require])
        require 'rails'
        require 'adam/rails'
        require File.expand_path("#{options[:require]}/config/environment.rb")
        ::Rails.application.eager_load!
      else
        require options[:require]
      end
    end

    def validate!
      options[:queues] << 'default' if options[:queues].empty?
      options[:queues].shuffle!

      if !File.exist?(options[:require]) ||
         (File.directory?(options[:require]) && !File.exist?("#{options[:require]}/config/application.rb"))
        logger.info "=================================================================="
        logger.info "  Please point adam to a Rails 3 application or a Ruby file    "
        logger.info "  to load your worker classes with -r [DIR|FILE]."
        logger.info "=================================================================="
        logger.info @parser
        die(1)
      end
    end

    def parse_options(argv)
      opts = {}

      @parser = OptionParser.new do |o|
         o.on "-q", "--queue QUEUE,WEIGHT", "Queue to process, with optional weight" do |arg|
          q, weight = arg.split(",")
          parse_queues(opts, q, weight)
        end

        o.on "-v", "--verbose", "Print more verbose output" do
          Adam.logger.level = ::Logger::DEBUG
        end

        o.on '-e', '--environment ENV', "Application environment" do |arg|
          opts[:environment] = arg
        end

        o.on '-t', '--timeout NUM', "Shutdown timeout" do |arg|
          opts[:timeout] = arg.to_i
        end

        o.on '-r', '--require [PATH|DIR]', "Location of Rails application with workers or file to require" do |arg|
          opts[:require] = arg
        end

        o.on '-c', '--concurrency INT', "processor threads to use" do |arg|
          opts[:concurrency] = arg.to_i
        end

        o.on '-P', '--pidfile PATH', "path to pidfile" do |arg|
          opts[:pidfile] = arg
        end

        o.on '-C', '--config PATH', "path to YAML config file" do |arg|
          opts[:config_file] = arg
        end

        o.on '-V', '--version', "Print version and exit" do |arg|
          puts "Adam #{Adam::VERSION}"
          die(0)
        end
      end

      @parser.banner = "adam [options]"
      @parser.on_tail "-h", "--help", "Show help" do
        logger.info @parser
        die 1
      end
      @parser.parse!(argv)
      opts
    end

    def write_pid
      if path = options[:pidfile]
        File.open(path, 'w') do |f|
          f.puts Process.pid
        end
      end
    end

    def parse_config(cli)
      opts = {}
      if cli[:config_file] && File.exist?(cli[:config_file])
        opts = YAML.load_file cli[:config_file]
        queues = opts.delete(:queues) || []
        queues.each { |name, weight| parse_queues(opts, name, weight) }
      end
      opts
    end

    def parse_queues(opts, q, weight)
      (weight || 1).to_i.times do
       (opts[:queues] ||= []) << q
      end
    end
  end
end

# Author::    Mohammad A. Ali  (mailto:oldmoe@gmail.com)
# Copyright:: Copyright (c) 2008 eSpace, Inc.
# License::   Distributes under the same terms as Ruby

require 'fiber'

class Fiber
  
  #Attribute Reference--Returns the value of a fiber-local variable, using
  #either a symbol or a string name. If the specified variable does not exist,
  #returns nil.
  def [](key)
    local_fiber_variables[key]
  end
  
  #Attribute Assignment--Sets or creates the value of a fiber-local variable,
  #using either a symbol or a string. See also Fiber#[].
  def []=(key,value)
    local_fiber_variables[key] = value
  end
  
  private
  
  def local_fiber_variables
    @local_fiber_variables ||= {}
  end
end

class FiberPool

  # gives access to the currently free fibers
  attr_reader :fibers
  attr_reader :busy_fibers

  # Code can register a proc with this FiberPool to be called
  # every time a Fiber is finished.  Good for releasing resources
  # like ActiveRecord database connections.
  attr_accessor :generic_callbacks

  # Prepare a list of fibers that are able to run different blocks of code
  # every time. Once a fiber is done with its block, it attempts to fetch
  # another one from the queue
  def initialize(count = 100)
    @fibers,@busy_fibers,@queue,@generic_callbacks = [],{},[],[]
    count.times do |i|
      fiber = Fiber.new do |block|
        loop do
          block.call
          # callbacks are called in a reverse order, much like c++ destructor
          Fiber.current[:callbacks].pop.call while Fiber.current[:callbacks].length > 0
          generic_callbacks.each do |cb|
            cb.call
          end
          unless @queue.empty?
            block = @queue.shift
          else
            @busy_fibers.delete(Fiber.current.object_id)
            @fibers.unshift Fiber.current
            block = Fiber.yield
          end
        end
      end
      fiber[:callbacks] = []
      fiber[:em_keys] = []
      @fibers << fiber
    end
  end

  # If there is an available fiber use it, otherwise, leave it to linger
  # in a queue
  def spawn(&block)
    if fiber = @fibers.shift
      fiber[:callbacks] = []
      @busy_fibers[fiber.object_id] = fiber
      fiber.resume(block)
    else
      @queue << block
    end
    self # we are keen on hiding our queue
  end

end