include_recipe "apt::default"
include_recipe "acme"

HOST = node["host"]

apt_update "keep it fresh" do
  action :update
end

# Install nginx
apt_package "nginx"
service "nginx" do
 supports %w(start stop status enable disable)
 action :enable
end

template "/etc/nginx/sites-available/default" do
  source "nginx-default-site.erb"
  notifies :start, "service[nginx]", :immediately
end

# Fetch SSL certificates for all relevant domains.
CERT_DIRECTORY = "/etc/letsencrypt/live"
directory "#{CERT_DIRECTORY}/haproxy" do
  recursive true
  owner "root"
  group "root"
end

ssl_domains = node["sites"].map { |s| s[:host] } << HOST
ssl_domains.each do |ssl_domain|
  acme_certificate "#{ssl_domain}" do
    crt "#{CERT_DIRECTORY}/#{ssl_domain}.crt"
    key "#{CERT_DIRECTORY}/#{ssl_domain}.key"
    chain "#{CERT_DIRECTORY}/#{ssl_domain}.pem"
    wwwroot "/var/www/html"
  end

  execute "concat fullchain and priv keys" do
    command "cat #{ssl_domain}.crt #{ssl_domain}.pem #{ssl_domain}.key > #{ssl_domain}.together.pem"
    cwd CERT_DIRECTORY
    user "root"
    group "root"
  end

  execute "set correct permissions for together.key" do
    command "chmod 777 #{ssl_domain}.together.pem"
    cwd CERT_DIRECTORY
    user "root"
    group "root"
  end

  execute "link together.pem to haproxy cert directory" do
    command "ln -sf #{CERT_DIRECTORY}/#{ssl_domain}.together.pem #{CERT_DIRECTORY}/haproxy/#{ssl_domain}.pem"
    user "root"
    group "root"
  end
end

# Install haproxy
apt_package "haproxy"
service "haproxy" do
 supports %w(start stop status enable disable)
 action :enable
end

# Configure haproxy
template "/etc/haproxy/haproxy.cfg" do
  source "haproxy.cfg.erb"
  variables({
    host: HOST,
    stats: {
      username: data_bag_item("haproxy", "stats")["username"],
      password: data_bag_item("haproxy", "stats")["password"],
      path: "/statz",
      port: 12345
    },
    sites: node["sites"],
    localhost_port: 4444,
    ingress_controller_host: "localhost:32042"
  })
  notifies :start, "service[haproxy]", :delayed
end

# Verify generated haproxy config
execute "haproxy -c -V -f /etc/haproxy/haproxy.cfg"

service "nginx" do
  action :restart
end

service "haproxy" do
  action :restart
end
