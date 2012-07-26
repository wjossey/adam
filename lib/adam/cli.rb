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
require 'adam/manager'
require 'em-synchrony'
module Adam
  class CLI
    include Singleton
    include Util

    SIZE = 250

    def initialize(options={})
      @code = nil
      @interrupt_mutex = Mutex.new
      @interrupted = false      
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
      #Wrap everything in a synchrony block, as AMQP needs it
      EM.synchrony do
        begin
          @manager = Adam::Manager.new(options.merge!({:queues => queues}))
          @manager.run!                
        rescue Interrupt
          logger.info "Shutting down"
          exit(0)
        end
      end
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

    def queues
      @class_names ||= Adam::Worker.classes.map! {|class_name| (eval class_name.to_s).adam_options["queue"]}.uniq
    end

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