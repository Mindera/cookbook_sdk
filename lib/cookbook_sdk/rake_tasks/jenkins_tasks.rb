require 'cookbook_sdk/rake_tasks'
require 'json'

namespace :jenkins do
  desc 'Generate attribute json file for image creation'
  task :pipeline_version do
    attributes_file = File.join('provision', 'attributes.json')
    pipeline_version = ENV['PIPELINE_VERSION']

    raise '$PIPELINE_VERSION cannot be null or empty' if pipeline_version.nil? || pipeline_version.empty?

    attributes = {
      'pipeline_version' => pipeline_version
    }

    File.open(attributes_file, 'w') do |f|
      f.write(attributes.to_json)
    end
  end

  desc 'Create attribute json file for cluster deployment'
  task :attributes do
    begin
      image_output_file = File.read(File.join('.', '_aws_image.output.json'))
      image_output = JSON.parse(image_output_file)
    rescue StandardError => err
      raise err
    end

    environment = ENV['ENVIRONMENT']
    environment = 'test' if environment.nil? || environment.empty?

    attributes_file = File.join('provision', 'attributes.json')
    attributes = {
      'image_id' => image_output['ami_id'],
      'environment' => environment
    }

    File.open(attributes_file, 'w') do |f|
      f.write(attributes.to_json)
    end
  end
end
