require 'adam/client'
require 'adam/core_ext'

module Adam

  module Worker
    def self.included(base)
      @classes ||= []
      @classes << base.name
      base.extend(ClassMethods)
      base.class_attribute :adam_options_hash
    end

    def self.classes
      @classes
    end

    def logger
      Adam.logger
    end

    module ClassMethods
      def publish(*args)
        client_publish('class' => self, 'args' => args)
      end

      ##
      # Allows customization for this type of Worker.
      # Legal options:
      #
      #   :queue - use a named queue for this Worker, default 'default'
      #   :retry - enable the RetryJobs middleware for this Worker, default *true*
      #   :backtrace - whether to save any error backtrace in the retry payload to display in web UI,
      #      can be true, false or an integer number of lines to save, default *false*
      def adam_options(opts={})
        self.adam_options_hash = get_adam_options.merge(stringify_keys(opts || {}))
      end

      DEFAULT_OPTIONS = {'retry' => true, 'queue' => 'default', 'backtrace' => true, 'passive' => false, 'durable' => false, 'auto_delete' => false, 'internal' => false, 'nowait' => false}

      def get_adam_options
        self.adam_options_hash ||= DEFAULT_OPTIONS
      end

      def stringify_keys(hash) # :nodoc:
        hash.keys.each do |key|
          hash[key.to_s] = hash.delete(key)
        end
        hash
      end

      def client_publish(*args)
        Adam::Client.publish(*args)
      end
    end
  end
end