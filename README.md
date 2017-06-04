## Kubernetes cookbooks

Use [Chef](https://www.chef.io/) to manage a [Kubernetes](https://kubernetes.io/) cluster.

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
3. Install [Knife Zero](http://knife-zero.github.io/20_getting_started/) so you can use Chef without
  having to setup a Chef server
    ```
    gem install knife-zero
    ```
4. Bootstrap your master node:
    ```
    knife zero bootstrap k8s-master --override-runlist "k8s::setup-master"
    ```
5. Bootstrap your minion node(s) (run this for each node)
    ```
    knife zero bootstrap k8s-node --override-runlist "k8s::setup-node"
    ```
