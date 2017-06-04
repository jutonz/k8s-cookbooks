# knife zero bootstrap kb-master
# knife zero converge "name:kb-master" --override-runlist "k8s::setup-master"

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

execute "kubeadm reset"

execute "kubeadm init" do
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
    kubeadm_join_cmd: "kubeadm join --token <token> <master-ip>:<master-port>"
  })
end
