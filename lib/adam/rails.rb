require 'adam/extensions/active_record'
require 'adam/extensions/action_mailer'
module Adam
  def self.hook_rails!
    return unless Adam.options[:enable_rails_extensions]
    if defined?(ActiveRecord)
      ActiveRecord::Base.extend(Adam::Extensions::ActiveRecord)
      ActiveRecord::Base.send(:include, Adam::Extensions::ActiveRecord)
    end

    if defined?(ActionMailer)
      ActionMailer::Base.extend(Adam::Extensions::ActionMailer)
    end
  end

  class Rails < ::Rails::Engine
    config.autoload_paths << File.expand_path("#{config.root}/app/workers") if File.exist?("#{config.root}/app/workers")

    initializer 'adam' do
      Adam.hook_rails!
    end
  end if defined?(::Rails)
end