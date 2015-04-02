require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:test) do |task|
    task.fail_on_error = false
  end

  task :default => :test
rescue LoadError
  puts 'Error loading files'
end
