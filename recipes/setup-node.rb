# knife zero bootstrap kb-master
# knife zero converge "name:kb-node" --override-runlist "k8s::setup-node"

include_recipe "apt::default"

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

# TODO need vpc such that node can communicate w/ master on port 6443
execute "kubeadm reset"
token = data_bag_item("secrets", "kubeadm_token")["key"]
execute "kubeadm join --token #{token} #{node["kubeadm"]["master_url"]}" do
  user "root"
end

# Set a motd explaining how to join nodes to the cluster
template "/etc/motd" do
  user "root"
  source "motd-node.erb"
end
