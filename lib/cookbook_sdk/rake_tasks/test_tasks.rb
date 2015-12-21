
module CookbookSdk
  # Test Tasks
  module Raketasks
    extend Rake::DSL

    desc 'Run all fast tests.'
    task :test => ['test:foodcritic', 'test:rubocop', 'test:rspec']

    namespace :test do
      desc 'Runs Foodcritic linting'
      task :foodcritic do
        foodcritic
      end

      desc 'Runs unit tests'
      task :rspec do
        rspec
      end

      desc 'Runs unit tests'
      task :rubocop do
        rubocop
      end

      ### Continous Integration
      desc 'Runs all tests when run in a CI environment'
      task :ci do
        error = false
        error = foodcritic(false) || error
        error = rubocop(false) || error
        error = rspec(false) || error
        exit error ? 1 : 0
      end
    end
  end
end

def foodcritic(exit_on_error = true)
  foodcritic_rules = File.join(File.dirname(__FILE__), '../../foodcritic/rules')
  cmd = "chef exec foodcritic -f any -P --include #{foodcritic_rules} ."
  banner("Running '#{cmd}' ...")
  run_command(cmd, exit_on_error)
end

def rspec(exit_on_error = true)
  files = FileList[File.join(Dir.pwd, 'test', 'unit', '**/test_*.rb')]
  cmd = "chef exec rspec #{files} --format doc"
  banner("Running '#{cmd}' ...")
  run_command(cmd, exit_on_error)
end

def rubocop(exit_on_error = true)
  cmd = 'chef exec rubocop'
  banner("Running '#{cmd}' ...")
  run_command(cmd, exit_on_error)
end
