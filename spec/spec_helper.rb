require 'bundler'
Bundler.setup(:default, :spec)
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require('support/matchers')
require('ruby_cqrs')

require('fixture/typical_domain')
