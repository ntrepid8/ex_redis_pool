# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.

  # Ubuntu 16.04 LTS
  config.vm.box = "ubuntu/xenial64"

  # port forwarding
  config.vm.network "forwarded_port", guest: 6379, host: 6379  # Redis

  # provider
  config.vm.provider "virtualbox" do |vb|
    # basic
    vb.memory = 2048
    vb.cpus = 2

    # motherboard
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--pae", "on"]

    # NIC 1
    vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y redis-server

    # update redis config so we can access it from the host
    sudo sed -i -- 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/redis/redis.conf

    # restart redis
    sudo service redis-server restart

    # done
    echo 'done!'
  SHELL
end
