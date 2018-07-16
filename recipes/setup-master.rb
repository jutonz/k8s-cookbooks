# knife solo prepare k8s-master
# knife solo cook k8s-master --override-runlist "k8s::setup-master"

SITE = "k8s-master.jutonz.com"

include_recipe "apt::default"

group "k8s" do
  action :create
end

user "k8s" do
  gid "k8s"
  shell "/bin/bash"
  manage_home true
  home "/home/k8s"
  system true
  action :create
end

execute "adduser k8s sudo"

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

# Install baseline deps
%w(
  apt-transport-https
  ca-certificates
  curl
  software-properties-common
).each { |pkg| apt_package(pkg) }

# Install docker-ce
apt_repository "docker-ce" do
  uri "https://download.docker.com/linux/ubuntu"
  key "https://download.docker.com/linux/ubuntu/gpg"
  components %w(stable)
  distribution "bionic"
end
apt_update do
  action :update
end
apt_package "docker-ce"

# Install kubernetes dependent packages
%w(
  kubelet
  kubectl
  kubernetes-cni
  kubeadm
).each { |pkg| apt_package(pkg) }

# Pods inherit /etc/resolv.conf from the node on which they're scheduled.
# The kubedns pod will always run on the master node.
directory "/etc/resolvconf/resolv.conf.d" do
  recursive true
  owner "root"
  group "root"
end
file "/etc/resolvconf/resolv.conf.d/base" do
  content "nameserver 8.8.8.8"
  owner "root"
  group "root"
end

execute "kubeadm reset -f" do
  user "root"
end

token = data_bag_item("secrets", "kubeadm_token")["key"]
execute "kubeadm init --token #{token} --pod-network-cidr=192.168.0.0/16" do
  user "root"
  not_if { ::File.exists?("/etc/kubernetes/admin.conf") }
end

directory "/home/k8s/.kube" do
  user "k8s"
  group "k8s"
end

execute "cp /etc/kubernetes/admin.conf /home/k8s/.kube/admin.conf"
execute "chown admin.conf" do
  command "chown k8s:k8s /home/k8s/.kube/admin.conf"
end

template "/home/k8s/.bashrc" do
  owner "k8s"
  source "bashrc"
end

# Apply a standard network config for kubeadm managed k8s
# See http://docs.projectcalico.org/v2.2/getting-started/kubernetes/installation/hosted/kubeadm/
remote_file "/home/k8s/calico.yaml" do
  owner "k8s"
  source "https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml"
  #source "https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml"
  #source "http://docs.projectcalico.org/v2.2/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml"
end
execute "apply network config" do
  user "root"
  command "KUBECONFIG=/home/k8s/.kube/admin.conf kubectl apply -f /home/k8s/calico.yaml"
  # TODO add only_if
end

# Install nginx ingress controller
# https://github.com/kubernetes/ingress-nginx/blob/master/deploy/README.md
networking_dir = "/home/k8s/ingress-controller"
directory networking_dir do
  owner "k8s"
end
files = %w(
  namespace
  default-backend
  tcp-services-configmap
  udp-services-configmap
  rbac
).each do |file|
  remote_file "#{networking_dir}/#{file}.yaml" do
    source "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/#{file}.yaml"
    owner "k8s"
  end
  execute "KUBECONFIG=/home/k8s/.kube/admin.conf kubectl apply -f #{networking_dir}/#{file}.yaml" do
    user "k8s"
  end
end

template "#{networking_dir}/ingress-controller-configmap.yaml" do
  source "ingress-controller-configmap.yaml"
end
execute "KUBECONFIG=/home/k8s/.kube/admin.conf kubectl apply -f #{networking_dir}/ingress-controller-configmap.yaml" do
  user "k8s"
end

# Customize ingress controller pod to always run on master (it seems pods on
# nodes cannot communicate with the master pod...something with this setup)
template "#{networking_dir}/ingress-controller-with-rbac.yaml"
execute "KUBECONFIG=/home/k8s/.kube/admin.conf kubectl apply -f #{networking_dir}/ingress-controller-with-rbac.yaml" do
  user "k8s"
end

template "#{networking_dir}/baremetal-service-nodeport.yaml" do
  variables({ node_port: "32042" })
end
execute "KUBECONFIG=/home/k8s/.kube/admin.conf kubectl apply -f #{networking_dir}/baremetal-service-nodeport.yaml" do
  user "k8s"
end

# Remove master taint to allow scheduling pods on master node
execute "KUBECONFIG=/home/k8s/.kube/admin.conf kubectl taint nodes --all node-role.kubernetes.io/master-" do
  user "k8s"
end

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
