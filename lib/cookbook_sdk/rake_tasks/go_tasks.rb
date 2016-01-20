require 'cookbook_sdk/rake_tasks'
require 'json'

namespace :go do
  desc 'Generate attribute json file for image creation'
  task :image_attr_json do
    rpm_version_file = File.join('../rpm_version')
    attributes_file = File.join('provision', 'attributes.json')

    version = nil
    File.open(rpm_version_file, 'r') do |output|
      version = output.read.strip
    end

    fail "'rpm_version' file should have a valid rpm version" if version.nil? || version.empty?

    attributes = { 'pipeline' => { 'app_version' => "#{version}" } }

    File.open(attributes_file, 'w') do |f|
      f.write(attributes.to_json)
    end
  end

  desc 'Create attribute json file for cluster deployment'
  task :cluster_attr_json do
    begin
      image_output_file = File.read(File.join('.', '_aws_image.output.json'))
      image_output = JSON.parse(image_output_file)
    rescue StandardError => err
      raise err
    end

    environment = ENV['ENVIRONMENT']
    environment = 'test' if environment.nil? || environment.empty?

    action = ENV['ACTION'] || nil
    actions = %w(create destroy update)
    fail "'ACTION' should be one of #{actions}" unless actions.include? action

    attributes_file = File.join('provision', 'attributes.json')
    attributes = {
      'pipeline' => {
        'image_id' => image_output['ami_id'],
        'environment' => environment
      }
    }

    File.open(attributes_file, 'w') do |f|
      f.write(attributes.to_json)
    end
  end
end
