# knife solo prepare k8s-master
# knife solo cook k8s-master --override-runlist "k8s::setup-master"

SITE = "k8s-master.jutonz.com"

include_recipe "apt::default"

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
  kubeadm
).each { |pkg| apt_package(pkg) }

execute "kubeadm reset"

token = data_bag_item("secrets", "kubeadm_token")["key"]
execute "kubeadm init --token #{token} --apiserver-advertise-address 99.111.155.95 --apiserver-bind-port 443" do
  user "root"
  not_if { ::File.exists?("/etc/kubernetes/admin.conf") }
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

# Store tls keys in a secret
# TODO: make this its own recipe so we can update secret as tls certs rotate?
#execute "KUBECONFIG=/home/ubuntu/admin.conf kubectl create secret tls tls-secret --key /etc/ssl/mycerts/#{SITE}.key --cert /etc/ssl/mycerts/#{SITE}.crt"

#execute "KUBECONFIG=/home/ubuntu/admin.conf kubectl taint nodes --all node-role.kubernetes.io/master-" do
  #user "ubuntu"
#end

# Set a motd explaining how to join nodes to the cluster
template "/etc/motd" do
  user "root"
  source "motd-master.erb"
  variables({
    kubeadm_join_cmd: "kubeadm join --token #{data_bag_item("secrets", "kubeadm_token")["key"]} #{node["kubeadm"]["master_url"]}"
  })
end
