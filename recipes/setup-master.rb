# knife zero bootstrap kb-master
# knife zero converge "name:kb-master" --override-runlist "k8s::setup-master"

include_recipe "apt::default"
include_recipe "acme"

group "ubuntu" do
  action :create
end

user "ubuntu" do
  gid "ubuntu"
  shell "/bin/bash"
  manage_home true
  home "/home/ubuntu"
  system true
  action :create
end

execute "adduser ubuntu sudo"

apt_package "apt-transport-https"

bash "add apt keys for kubernetes" do
  code "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
end

file "/etc/apt/sources.list.d/kubernetes.list" do
  content "deb http://apt.kubernetes.io/ kubernetes-xenial main"
end

apt_update "keep it fresh" do
  action :update
end

# Install docker
apt_package "docker-engine"

# Install kubernetes dependent packages
%w(
  kubelet
  kubectl
  kubernetes-cni
).each { |pkg| apt_package(pkg) }

# Install kubeadm, which automates k8s setup
# Optionally skip this and setup k8s manually
# See https://kubernetes.io/docs/getting-started-guides/kubeadm/
apt_package "kubeadm"

# Install nginx so we can respond to http cert verification
apt_package "nginx"
service "nginx" do
  action :nothing
  supports %i(restart reload status)
end

site = "k8s-master.jutonz.com"
template "/etc/nginx/sites-available/default" do
  source "default-site-available.erb"
  variables({
    site: site
  })
  notifies :start, "service[nginx]", :immediately
end

directory "/etc/ssl/mycerts"

# Setup letsencrypt certs for https
acme_certificate site do
  wwwroot "/var/www/html"
  crt "/etc/ssl/mycerts/#{site}.crt"
  chain "/etc/ssl/mycerts/#{site}-chain.crt"
  key "/etc/ssl/mycerts/#{site}.key"
  not_if { ::File.exists?("/etc/ssl/mycerts/#{site}.crt") }
  notifies :stop, "service[nginx]", :immediately
end

execute "kubeadm reset"

token = data_bag_item("secrets", "kubeadm_token")["key"]
execute "kubeadm init --token #{token}" do
  user "root"
  not_if { ::File.exist?("/etc/kubernetes/admin.conf") }
end

execute "cp /etc/kubernetes/admin.conf /home/ubuntu/admin.conf"
execute "chown admin.conf" do
  command "chown ubuntu:ubuntu /home/ubuntu/admin.conf"
end

template "/home/ubuntu/.bashrc" do
  owner "ubuntu"
  source "bashrc"
end

# Apply a standard network config for kubeadm managed k8s
# See http://docs.projectcalico.org/v2.2/getting-started/kubernetes/installation/hosted/kubeadm/
remote_file "/home/ubuntu/calico.yaml" do
  owner "ubuntu"
  source "http://docs.projectcalico.org/v2.2/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml"
end
execute "apply network config" do
  user "root"
  command "KUBECONFIG=/home/ubuntu/admin.conf kubectl apply -f /home/ubuntu/calico.yaml"
  # TODO add only_if
end

# Set a motd explaining how to join nodes to the cluster
template "/etc/motd" do
  user "root"
  source "motd-master.erb"
  variables({
    kubeadm_join_cmd: "kubeadm join --token #{data_bag_item("secrets", "kubeadm_token")["key"]} #{node["kubeadm"]["master_url"]}"
  })
end
