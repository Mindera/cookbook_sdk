# Etsy foodcritic rules
# Source: https://github.com/etsy/foodcritic-rules

@coreservicepackages = ["httpd", "node", "java", "nginx"]
@corecommands = ["yum -y", "yum install", "yum reinstall", "yum remove", "mkdir", "useradd", "usermod", "touch"]

rule "ETSY001", "Package or yum_package resource used with :upgrade action" do
  tags %w{correctness recipe etsy}
  recipe do | ast|
    pres = find_resources(ast, :type => 'package').find_all do |cmd|
      cmd_str = (resource_attribute(cmd, 'action') || resource_name(cmd)).to_s
      cmd_str.include?('upgrade')
    end
    ypres = find_resources(ast, :type => 'yum_package').find_all do |cmd|
      cmd_str = (resource_attribute(cmd, 'action') || resource_name(cmd)).to_s
      cmd_str.include?('upgrade')
    end
  pres.concat(ypres).map{|cmd| match(cmd)}
  end
end

rule "ETSY006", "Execute resource used to run chef-provided command" do
  tags %w{style recipe etsy}
  recipe do |ast|
    find_resources(ast, :type => 'execute').find_all do |cmd|
      cmd_str = (resource_attribute(cmd, 'command') || resource_name(cmd)).to_s
      @corecommands.any? { |corecommand| cmd_str.include? corecommand }
    end.map{|c| match(c)}
  end
end

rule "ETSY007", "Package or yum_package resource used to install core package without specific version number" do
  tags %w{style recipe etsy}
  recipe do |ast,filename|
    pres = find_resources(ast, :type => 'package').find_all do |cmd|
      cmd_str = (resource_attribute(cmd, 'version') || resource_name(cmd)).to_s
      cmd_action = (resource_attribute(cmd, 'action') || resource_name(cmd)).to_s
      cmd_str == resource_name(cmd) && @coreservicepackages.any? { |svc| resource_name(cmd) == svc } && cmd_action.include?('install')
    end
    ypres = find_resources(ast, :type => 'yum_package').find_all do |cmd|
      cmd_str = (resource_attribute(cmd, 'version') || resource_name(cmd)).to_s
      cmd_action = (resource_attribute(cmd, 'action') || resource_name(cmd)).to_s
      cmd_str == resource_name(cmd) && @coreservicepackages.any? { |svc| resource_name(cmd) == svc } && cmd_action.include?('install')
    end
    pres.concat(ypres).map { |cmd| match(cmd) }
  end
end
