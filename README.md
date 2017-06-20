## Kubernetes cookbooks

Use [Chef](https://www.chef.io/) and [kubeadm](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/) to manage a [Kubernetes](https://kubernetes.io/) cluster.

### Getting started

1. Spin up some instances where you want to run kubernetes
2. Add ssh aliases to `~/.ssh/config` for each of those nodes, e.g.

    ```
    Host k8s-master
      HostName 1.2.3.4
      User root
      IdentityFile ~/.ssh/digitalocean

    Host k8s-node
      HostName 1.2.3.5
      User root
      IdentityFile ~/.ssh/digitalocean
    ```
3. Install [Knife Solo](http://matschaffer.github.io/knife-solo/) so you can use Chef without
  having to setup a Chef server
    ```bash
    $ gem install knife-solo
    ```
4. Open "k8s cookbooks data bag secret" from 1password and copy the password to your clipboard.
5. Write the data bag secret key to disk so you can access encrypted secrets
   ```bash
   $ pbpaste > .chef/data_bag_secret_file
   ```
6. Bootstrap your master node:
    ```bash
    $ knife solo prepare k8s-master
    $ knife solo cook k8s-master --override-runlist "k8s::setup-master"
    ```
7. Bootstrap your minion node(s) (run this for each node)
    ```bash
    $ knife solo prepare k8s-node
    $ knife solo cook k8s-node --override-runlist "k8s::setup-node"
    ```
8. Verify that your nodes are registered with the master
   ```bash
   $ ssh k8s-master
   $ su ubuntu
   $ kubectl get nodes
   ```
