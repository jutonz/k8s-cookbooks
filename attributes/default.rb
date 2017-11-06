default["acme"]["contact"] = "mailto:jutonz42@gmail.com"

MASTER_PRIVATE_IP = "192.168.1.85".freeze

default["kubeadm"] = {
  "master_private_ip" => MASTER_PRIVATE_IP,
  "master_url" => "#{MASTER_PRIVATE_IP}:6443"
}

default["addr"] = {
  "domain" => "homepage-test.notmalware.biz",
  "ip"     => "99.111.155.95"
}

#default["chef_client"]["config"] = {
  #"encrypted_data_bag_secret" => File.expand_path("../../tmp/data_bag_secret_file", __FILE__)
#}
