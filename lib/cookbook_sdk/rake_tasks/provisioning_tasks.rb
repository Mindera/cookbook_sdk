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
    RUN_LIST = ENV['RUN_LIST']
    DEBUG = ENV['DEBUG']
    BERKS = ENV['BERKS'] || false

    desc 'Prepare chef-zero environment, and run it.'
    task all: ['chef:prepare', 'chef:run', 'chef:clean']

    namespace :chef do
      desc 'Prepare chef-zero environment to run.'
      task :prepare do
        clean(TARGET_FOLDER)
        if BERKS
          berks_update(base_dir)
          berks_vendor(base_dir, TARGET_FOLDER)
        else
          chefdk_update(base_dir)
          chefdk_export(base_dir, TARGET_FOLDER)
        end
        copy_attributes_file(base_dir, TARGET_FOLDER)
        copy_data_bags(base_dir, TARGET_FOLDER)
        create_custom_client_rb(TARGET_FOLDER, SDK_CONFIGURATION, !BERKS)
      end

      desc 'Run chef-zero in a pre prepared environment.'
      task :run do
        run_chef_zero(TARGET_FOLDER, CUSTOM_NAMED_LIST, RUN_LIST, DEBUG)
      end

      desc 'Clean generated folder'
      task :clean do
        clean(TARGET_FOLDER)
      end
    end
  end
end

def _run_command(cmd, base_dir)
  banner("Running '#{cmd}' in #{base_dir}...")
  Dir.chdir base_dir do
    run_command(cmd, true)
  end
end

def berks_update(base_dir)
  _run_command('berks install', base_dir)
  _run_command('berks update', base_dir)
end

def berks_vendor(base_dir, target_folder)
  _run_command("berks vendor #{target_folder}/cookbooks", base_dir)
end

def chefdk_update(base_dir)
  _run_command('chef update', base_dir)
end

def chefdk_export(base_dir, target_folder)
  _run_command("chef export #{target_folder} --force", base_dir)
end

def read_configuration(configuration_file)
  file = nil

  if File.exist?(configuration_file)
    file = File.read(configuration_file)
  elsif File.exist?("../#{configuration_file}")
    file = File.read(configuration_file)
  end
  return nil if file.nil?

  data_hash = JSON.parse(file, symbolize_names: true)
  data_hash
rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError => e
  puts "Problem reading #{configuration_file} - #{e}"
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

def create_custom_client_rb(target_folder, configuration_file, copy_original)
  banner("Creating custom 'client.rb' in #{target_folder} ...")
  original_client_rb = File.join(target_folder, 'client.rb')
  custom_client_rb = File.join(target_folder, 'custom_client.rb')

  config = read_configuration(configuration_file)

  begin
    FileUtils.copy_file(original_client_rb, custom_client_rb) if copy_original
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

def copy_attributes_file(base_dir, target_folder)
  attributes_file = File.join(base_dir, 'attributes.json')
  return unless File.exist?(attributes_file)

  banner("Copying attributes file from #{attributes_file} to #{target_folder}...")
  FileUtils.cp_r(attributes_file, target_folder)
end

def run_chef_zero(target_folder, custom_named_run_list = nil, run_list = nil, debug = false)
  named_run_list = custom_named_run_list.nil? ? '' : "-n #{custom_named_run_list}"
  run_list = run_list.nil? ? '' : "-o #{run_list}"
  debug = !debug ? '' : '-l debug'

  attributes_file = File.join(target_folder, 'attributes.json')
  attributes = File.exist?(attributes_file) ? '-j attributes.json' : ''

  timestamp = Time.now.to_i
  cache_pid_file = "#{target_folder}/.chef/cache/chef-client-running_#{timestamp}.pid"
  lockfile = "--lockfile=#{cache_pid_file}"

  cmd = "chef exec chef-client -c custom_client.rb -z "
  cmd += "#{named_run_list} #{run_list} #{debug} #{attributes} #{cache_pid_file}"

  banner("Running '#{cmd}' inside folder '#{target_folder}' ...")

  Dir.chdir target_folder do
    run_command(cmd, true)
  end
end

def clean(target_folder)
  cmd = "rm -rf #{target_folder}/cookbooks"
  banner("Cleanning up the cookbooks cache folder with '#{cmd}' ...")
  run_command(cmd, true)
end
