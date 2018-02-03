DOMAIN = "gems.jutonz.com".freeze

include_recipe "apt::default"
include_recipe "acme"

apt_package "nginx"
service "nginx" do
  action :nothing
  supports %i(enable disable start stop restart reload status)
end

template "/etc/nginx/sites-available/default" do
  source "default-site-available.erb"
  variables({
    site: DOMAIN
  })
  notifies :start, "service[nginx]", :immediately
end

directory "/etc/ssl/mycerts"

# Setup letsencrypt certs for https
acme_certificate DOMAIN do
  wwwroot "/var/www/html"
  crt "/etc/ssl/mycerts/#{DOMAIN}.crt"
  chain "/etc/ssl/mycerts/#{DOMAIN}-chain.crt"
  key "/etc/ssl/mycerts/#{DOMAIN}.key"
  #not_if { ::File.exists?("/etc/ssl/mycerts/#{DOMAIN}.crt") }
  notifies :stop, "service[nginx]", :immediately
end

