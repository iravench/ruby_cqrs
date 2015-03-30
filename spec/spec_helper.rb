require 'bundler'
Bundler.setup(:default, :spec)

require_relative('support/matchers')

require_relative('../lib/ruby_cqrs')
require_relative('../lib/support/error')
require_relative('../lib/data/event_store')
require_relative('../lib/domain/aggregate_base')
require_relative('../lib/domain/aggregate_repository')
require_relative('../lib/domain/event')

require_relative('fixture/typical_domain')
