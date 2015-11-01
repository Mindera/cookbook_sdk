
module CookbookSdk
  # Provisioning Tasks
  module Raketasks
    extend Rake::DSL

    target_folder = '.target'

    desc 'Prepare chef-zero environment, and run it.'
    task prod: ['prod:prepare', 'prod:run']

    namespace :prod do
      desc 'Prepare chef-zero environment to run.'
      task :prepare do
        clean(target_folder)
        chefdk_update
        chefdk_export(target_folder)
        create_custom_client_rb(target_folder)
      end

      desc 'Run chef-zero in a pre prepared environment.'
      task :run do
        run_chef_zero(target_folder)
      end

      desc 'Clean generated folder'
      task :clean do
        clean(target_folder)
      end
    end
  end
end

def chefdk_update
  cmd = 'chef update'
  banner("Running '#{cmd}' ...")
  run_command(cmd, true)
end

def chefdk_export(target_folder)
  cmd = "chef export #{target_folder} --force"
  banner("Running '#{cmd}' ...")
  run_command(cmd, true)
end

# rubocop:disable Metrics/MethodLength
def create_custom_client_rb(target_folder)
  banner("Creating custom 'client.rb' in #{target_folder} ...")
  original_client_rb = File.join(Dir.pwd, target_folder, 'client.rb')
  custom_client_rb = File.join(Dir.pwd, target_folder, 'custom_client.rb')

  File.open(original_client_rb, 'rb') do |input|
    File.open(custom_client_rb, 'wb') do |output|
      while (buff = input.read(4096))
        output.write(buff)
      end
      output.write("
# To enable chef-solo without sudo.
# https://docs.chef.io/ctl_chef_client.html#run-as-non-root-user
cache_path '#{Dir.pwd}/#{target_folder}/.chef'
")
    end
  end
  puts "Writed a custom client.rb to '#{custom_client_rb}"
end
# rubocop:enable Metrics/MethodLength

def run_chef_zero(target_folder)
  cmd = 'chef-client --minimal-ohai -c custom_client.rb -z'
  banner("Running '#{cmd}' inside folder '#{target_folder}' ...")

  # Magic here. With 'Bundler.with_clean_env' it found the gems!!! http://bundler.io/v1.3/man/bundle-exec.1.html
  Bundler.with_clean_env do
    Dir.chdir target_folder do
      run_command(cmd, true)
    end
  end
end

def clean(target_folder)
  cmd = "rm -rf #{target_folder}/cookbooks"
  banner("Cleanning up the cookbooks cache folder with '#{cmd}' ...")
  run_command(cmd, true)
end
