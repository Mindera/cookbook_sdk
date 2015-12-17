require 'cookbook_sdk/rake_tasks'
require 'json'

namespace :jenkins do
  desc 'Generate attribute json file for image creation'
  task :pipeline_version do
    attributes_file = File.join('provision', 'attributes.json')
    pipeline_version = ENV['PIPELINE_VERSION']

    fail '$PIPELINE_VERSION cannot be null or empty' if pipeline_version.nil? || pipeline_version.empty?

    attributes = {
      'pipeline_version' => "#{pipeline_version}"
    }

    File.open(attributes_file, 'w') do |f|
      f.write(attributes.to_json)
    end
  end

  desc 'Read image id and create attribute json file for cluster deployment'
  task :image_id do
    begin
      image_output_file = File.read(File.join('.', '_aws_image_output.json'))
      image_output = JSON.parse(image_output_file)
    rescue StandardError => err
      raise err
    end

    attributes_file = File.join('provision', 'attributes.json')
    attributes = {
      'image_id' => image_output['ami_id']
    }

    File.open(attributes_file, 'w') do |f|
      f.write(attributes.to_json)
    end
  end
end
