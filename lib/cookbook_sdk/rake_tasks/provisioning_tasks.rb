require 'json'
require 'fileutils'

module CookbookSDK
  # Provisioning Tasks
  module Raketasks
    extend Rake::DSL

    base_dir = Dir.pwd
    base_dir += '/provision' if File.directory?('provision')
    TARGET_FOLDER = File.join(base_dir, '.target')
    SDK_CONFIGURATION = 'cookbook_sdk.json'
    CUSTOM_NAMED_LIST = ENV['NAMED_RUN_LIST']
    DEBUG = ENV['DEBUG']

    desc 'Prepare chef-zero environment, and run it.'
    task all: ['chef:prepare', 'chef:run', 'chef:clean']

    namespace :chef do
      desc 'Prepare chef-zero environment to run.'
      task :prepare do

        clean(TARGET_FOLDER)
        chefdk_update(base_dir)
        chefdk_export(base_dir, TARGET_FOLDER)
        copy_data_bags(base_dir, TARGET_FOLDER)
        create_custom_client_rb(TARGET_FOLDER, SDK_CONFIGURATION)
      end

      desc 'Run chef-zero in a pre prepared environment.'
      task :run do
        run_chef_zero(TARGET_FOLDER, CUSTOM_NAMED_LIST, DEBUG)
      end

      desc 'Clean generated folder'
      task :clean do
        clean(TARGET_FOLDER)
      end
    end
  end
end

def chefdk_update(base_dir)
  cmd = 'chef update'
  banner("Running '#{cmd}' in #{base_dir}...")
  Dir.chdir base_dir do
    run_command(cmd, true)
  end
end

def chefdk_export(base_dir, target_folder)
  cmd = "chef export #{target_folder} --force"
  banner("Running '#{cmd}' in #{base_dir}...")
  Dir.chdir base_dir do
    run_command(cmd, true)
  end
end

def read_configuration(configuration_file)
  data_hash = nil

  begin
    file = File.read(configuration_file)
    data_hash = JSON.parse(file, symbolize_names: true)
  rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError => e
    puts "Problem reading #{configuration_file} - #{e}"
  end

  data_hash
end

def prepare_handlers(handlers)
  config_rb = ''

  handlers[:enabled].each do |enabled_handler|
    handler_config = handlers[:config][enabled_handler.to_sym]
    config_rb += %(

# #{enabled_handler} handler configuration
require 'cookbook_sdk/handlers/#{enabled_handler}'
#{enabled_handler}_handler_options = #{handler_config}
#{enabled_handler}_handler = Chef::Handler::Slack.new(#{enabled_handler}_handler_options)
start_handlers << #{enabled_handler}_handler
report_handlers << #{enabled_handler}_handler
exception_handlers << #{enabled_handler}_handler

)
  end
  config_rb
end

def cache_path_config(target_folder)
  %(
# To enable chef-client without sudo.
# https://docs.chef.io/ctl_chef_client.html#run-as-non-root-user
cache_path "#{target_folder}/.chef"
)
end

def create_custom_client_rb(target_folder, configuration_file)
  banner("Creating custom 'client.rb' in #{target_folder} ...")
  original_client_rb = File.join(target_folder, 'client.rb')
  custom_client_rb = File.join(target_folder, 'custom_client.rb')

  config = read_configuration(configuration_file)

  begin
    FileUtils.copy_file(original_client_rb, custom_client_rb)
    File.open(custom_client_rb, 'a') do |output|
      output.write(cache_path_config(target_folder))

      if config.nil?
        puts 'No configuration file found: custom_client.rb will not have any user custom configuration.'
      else
        output.write(prepare_handlers(config[:handlers]))
      end
    end
  rescue Errno::EACCES => e
    puts "Problem creating #{custom_client_rb} - #{e}"
  end

  puts "Writed a custom client.rb to '#{custom_client_rb}"
end

def copy_data_bags(base_dir, target_folder)
  data_bags_directory = File.join(base_dir, 'data_bags')
  return unless File.directory?(data_bags_directory)

  banner("Copying data_bags folder from #{data_bags_directory} to #{target_folder}...")
  FileUtils.cp_r(data_bags_directory, target_folder)
end

def run_chef_zero(target_folder, custom_named_run_list = nil, debug = false)
  named_run_list = custom_named_run_list.nil? ? '' : "-n #{custom_named_run_list}"
  debug = !debug ? '' : '-l debug'
  cmd = "chef exec chef-client -c custom_client.rb -z #{named_run_list} #{debug}"

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

  cmd = "rm -rf #{target_folder}/data_bags"
  banner("Cleanning up the data_bags with '#{cmd}' ...")
  run_command(cmd, true)
end
