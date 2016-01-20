require 'cookbook_sdk/ext/string'
require 'cookbook_sdk/rake_tasks/test_tasks'
require 'cookbook_sdk/rake_tasks/helper_tasks'
require 'cookbook_sdk/rake_tasks/provisioning_tasks'
require 'cookbook_sdk/rake_tasks/jenkins_tasks'
require 'cookbook_sdk/rake_tasks/go_tasks'
require 'English'

# Runs a shell command.
# If all good, return false.
# If error, return true.
# If error and exit_on_error, exit with the error code.
def run_command(cmd, exit_on_error = false)
  Bundler.with_clean_env do
    system(cmd)
    status = $CHILD_STATUS.exitstatus

    return false unless status != 0
    return true unless exit_on_error
    exit status
  end
end

def banner(text)
  puts
  puts text.cyan
end
