default['acme']['contact'] = "mailto:jutonz42@gmail.com"

default['kubeadm'] = {
  "master_url" => "k8s-master-home:443"
}

#default['chef_client']['config'] = {
  #"encrypted_data_bag_secret" => File.expand_path("../../tmp/data_bag_secret_file", __FILE__)
#}
