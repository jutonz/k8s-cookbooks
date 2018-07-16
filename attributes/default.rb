default["host"] = "totally.notmalware.biz"

default["sites"] = [
  {
    name: "registry",
    host: "registry.totally.notmalware.biz",
    backend: "k8s"
  }
  #{
    #name: "registry-port",
    #host: "registry.notmalware.biz:443",
    #backend: "k8s"
  #}
]

default['acme']['contact'] = "mailto:jutonz42@gmail.com"
default['acme']['endpoint'] = "https://acme-v01.api.letsencrypt.org"

default['kubeadm'] = {
  "master_url" => "k8s-master-home:6443"
}

#default['chef_client']['config'] = {
  #"encrypted_data_bag_secret" => File.expand_path("../../tmp/data_bag_secret_file", __FILE__)
#}
