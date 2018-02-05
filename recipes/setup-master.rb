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

# Install kubernetes dependent packages
%w(
  docker-engine
  kubelet
  kubectl
  kubernetes-cni
  kubeadm
).each { |pkg| apt_package(pkg) }

execute "kubeadm reset"

token = data_bag_item("secrets", "kubeadm_token")["key"]
execute "kubeadm init --token #{token} --pod-network-cidr=192.168.0.0/16 --feature-gates=CustomPodDNS=true" do
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
  source "https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml"
  #source "http://docs.projectcalico.org/v2.2/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml"
end
execute "apply network config" do
  user "root"
  command "KUBECONFIG=/home/ubuntu/admin.conf kubectl apply -f /home/ubuntu/calico.yaml"
  # TODO add only_if
end

# Install nginx ingress controller
# https://github.com/kubernetes/ingress-nginx/blob/master/deploy/README.md
networking_dir = "/home/ubuntu/ingress-controller"
directory networking_dir do
  owner "ubuntu"
end
files = %w(
  namespace
  default-backend
  configmap
  tcp-services-configmap
  udp-services-configmap
  rbac
  with-rbac
).each do |file|
  remote_file "#{networking_dir}/#{file}.yaml" do
    source "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/#{file}.yaml"
  end
  execute "KUBECONFIG=/home/ubuntu/admin.conf kubectl apply -f #{networking_dir}/#{file}.yaml" do
    user "ubuntu"
  end
end

template "#{networking_dir}/baremetal-service-nodeport.yaml" do
  variables({ node_port: "32042" })
end
execute "KUBECONFIG=/home/ubuntu/admin.conf kubectl apply -f #{networking_dir}/baremetal-service-nodeport.yaml" do
  user "ubuntu"
end

# Remove master taint to allow scheduling pods on master node
#execute "KUBECONFIG=/home/ubuntu/admin.conf kubectl taint nodes --all node-role.kubernetes.io/master-" do
  #user "ubuntu"
#end

# Set a motd explaining how to join nodes to the cluster
template "/etc/motd" do
  user "root"
  source "motd-master.erb"
  variables lazy {
    join_cmd = `kubeadm token create --print-join-command`.strip
    { kubeadm_join_cmd: join_cmd }
  }
  #variables({
    #kubeadm_join_cmd: "kubeadm join --token #{data_bag_item("secrets", "kubeadm_token")["key"]} #{node["kubeadm"]["master_url"]}"
  #})
end
