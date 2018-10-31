USER = "jutonz"
NODE_PORT = 32042

# https://github.com/kubernetes/ingress-nginx/blob/master/deploy/README.md
networking_dir = "/home/#{USER}/ingress-controller"
directory networking_dir do
  owner USER
end

remote_file "#{networking_dir}/mandatory.yaml" do
  owner USER
  source "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml"
end
execute "kubectl apply -f #{networking_dir}/mandatory.yaml" do
  user USER
end

template "#{networking_dir}/baremetal-service-nodeport.yaml" do
  variables({ node_port: NODE_PORT })
end
execute "kubectl apply -f #{networking_dir}/baremetal-service-nodeport.yaml" do
  user USER
end

#files = %w(
  #namespace
  #default-backend
  #tcp-services-configmap
  #udp-services-configmap
  #rbac
#).each do |file|
  #remote_file "#{networking_dir}/#{file}.yaml" do
    #source "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/#{file}.yaml"
    #owner USER
  #end
  #execute "kubectl apply -f #{networking_dir}/#{file}.yaml" do
    #user USER
  #end
#end

#template "#{networking_dir}/ingress-controller-configmap.yaml" do
  #source "ingress-controller-configmap.yaml"
#end
#execute "kubectl apply -f #{networking_dir}/ingress-controller-configmap.yaml" do
  #user USER
#end

 #Customize ingress controller pod to always run on master (it seems pods on
 #nodes cannot communicate with the master pod...something with this setup)
#template "#{networking_dir}/ingress-controller-with-rbac.yaml" do
  #source "ingress-controller-with-rbac.yaml"
#end
#execute "kubectl apply -f #{networking_dir}/ingress-controller-with-rbac.yaml" do
  #user USER
#end

#template "#{networking_dir}/baremetal-service-nodeport.yaml" do
  #variables({ node_port: NODE_PORT })
#end
#execute "kubectl apply -f #{networking_dir}/baremetal-service-nodeport.yaml" do
  #user USER
#end

 #Remove master taint to allow scheduling pods on master node
#execute "kubectl taint nodes --all node-role.kubernetes.io/master-" do
  #user USER
#end
