
namespace :help do
  desc 'Help about how to bump your cookbook.'
  task :bump do
    help_bump
  end

  desc 'Help about how to bump your cookbook.'
  task :kitchen do
    help_kitchen
  end
end

def help_bump
  title = 'Help: Bumping cookbooks'.gray.bold
  body = <<BODY

To bump your cookbook run the following command:
chef exec knife spork bump -z

Note: -z stands for local mode (chef-zero)
For more about 'knife spork' go to: http://jonlives.github.io/knife-spork/

BODY

  output_help(title, body)
end

def help_kitchen
  title = 'Help: Test Kitchen'.gray.bold
  body = <<BODY

Test kitchen is an awsome testing tool. It enables you to test your cookbook against
some virtual machine, container, or an instance in several cloud virtualization tecnologies.

Run rhe folling command to have the real kitchen help
chef exec knife --help

Note: You don't get nothing when run chef-provisioning cookbooks with kitchen.
For more about 'kitchen' go to: http://kitchen.ci/
BODY

  output_help(title, body)
end

def output_help(title, body)
  puts title
  puts body
end
