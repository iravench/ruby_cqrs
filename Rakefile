require 'rubygems'
require 'rake'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |task|
    task.fail_on_error = false
  end

  task :default => :spec
rescue LoadError
  puts 'Error loading files'
end
