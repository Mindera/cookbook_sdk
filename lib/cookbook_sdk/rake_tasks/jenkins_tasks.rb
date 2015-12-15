require 'cookbook_sdk/rake_tasks'
require 'json'

namespace :jenkins do
  desc 'Generate attribute json file for image creation'
  task :pipeline_version do
    attributes_file = File.join('provision', 'attributes.json')
    pipeline_version = ENV['PIPELINE_VERSION']

    raise '$PIPELINE_VERSION cannot be null or empty' if pipeline_version.nil? or pipeline_version.empty?

    attributes = {
      'pipeline_version' => "#{pipeline_version}"
    }

    File.open(attributes_file,"w") do |f|
      f.write(attributes.to_json)
    end
  end
end