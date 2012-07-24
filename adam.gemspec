# -*- encoding: utf-8 -*-
require File.expand_path('../lib/adam/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Weston Jossey"]
  gem.email         = ["weston.jossey@gmail.com"]
  gem.description   = gem.summary = "Message processing for Ruby using RabbitMQ"
  gem.homepage      = ""
  gem.license       = "LGPL-3.0"

  gem.executables   = ['adam', 'adamctl']
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- test/*`.split("\n")
  gem.name          = "adam"
  gem.require_paths = ["lib"]
  gem.version       = Adam::VERSION
  gem.add_dependency                  'amqp'
  gem.add_dependency                  'eventmachine'
  gem.add_dependency                  'connection_pool', '~> 0.9.0'
  gem.add_dependency                  'em-synchrony', '~> 1.0.2'
  gem.add_dependency                  'multi_json', '~> 1'
  gem.add_development_dependency      'minitest', '~> 3'
  gem.add_development_dependency      'sinatra'
  gem.add_development_dependency      'slim'
  gem.add_development_dependency      'rake'
  gem.add_development_dependency      'actionmailer', '~> 3'
  gem.add_development_dependency      'activerecord', '~> 3'
end
