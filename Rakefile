# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:spec].invoke
end

desc 'Run all checks (tests, rubocop, etc.)'
task :check do
  Rake::Task[:spec].invoke
  Rake::Task[:rubocop].invoke
end

task default: :check

desc 'Build and install gem locally'
task :install_local do
  Rake::Task[:build].invoke
  gemfile = Dir.glob('pkg/*.gem').last
  system "gem install #{gemfile}"
end

desc 'Run console with gem loaded'
task :console do
  require 'bundler/setup'
  require 'spyglasses'
  require 'pry'
  Pry.start
end 