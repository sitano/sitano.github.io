---
layout: post
title: Rebuild vagrant box
---

### Box repositories

* [https://cloud-images.ubuntu.com/vagrant/](https://cloud-images.ubuntu.com/vagrant/)
* [http://www.vagrantbox.es/](http://www.vagrantbox.es/)
* [https://github.com/mitchellh/vagrant/wiki/Available-Vagrant-Boxes](https://github.com/mitchellh/vagrant/wiki/Available-Vagrant-Boxes)
* [http://puppet-vagrant-boxes.puppetlabs.com/](http://puppet-vagrant-boxes.puppetlabs.com/)
* [http://www.packer.io/intro/getting-started/vagrant.html](http://www.packer.io/intro/getting-started/vagrant.html)
* [http://blog.phusion.nl/2013/11/08/docker-friendly-vagrant-boxes/](http://blog.phusion.nl/2013/11/08/docker-friendly-vagrant-boxes/)

### Upgrade

* [http://dominique.broeglin.fr/2011/08/09/squeeze-64-vagrant-base-box-upgrade.html](http://dominique.broeglin.fr/2011/08/09/squeeze-64-vagrant-base-box-upgrade.html)
* [http://kvz.io/blog/2013/01/16/vagrant-tip-keep-virtualbox-guest-additions-in-sync/](http://kvz.io/blog/2013/01/16/vagrant-tip-keep-virtualbox-guest-additions-in-sync/)
* [https://docs.vagrantup.com/v2/virtualbox/boxes.html](https://docs.vagrantup.com/v2/virtualbox/boxes.html)

### Building vagrant boxes with packer.io

* sample + few scripts [https://bitbucket.org/ariya/packer-vagrant-linux/](https://bitbucket.org/ariya/packer-vagrant-linux/)
* sample + few scripts [https://github.com/tech-angels/packer-templates](https://github.com/tech-angels/packer-templates)
* good ubuntu [https://github.com/ffuenf/vagrant-boxes/tree/master/packer/ubuntu-12.04.4-server-amd64](https://github.com/ffuenf/vagrant-boxes/tree/master/packer/ubuntu-12.04.4-server-amd64)
* good scripts [https://github.com/datenbetrieb/packer-boxdefinitions/tree/master/template/debian/scripts](https://github.com/datenbetrieb/packer-boxdefinitions/tree/master/template/debian/scripts)
* sample [https://github.com/flomotlik/packer-example](https://github.com/flomotlik/packer-example)

## Build a new environment

    $ mkdir /tmp/upgrade
    $ cd /tmp/upgrade
    $ vagrant init squeeze64
    $ vagrant up
    $ vagrant halt

At that point the VM is stoped. Launch it from the Virtual Box GUI and mount the guest tools (Host+D).

## Upgrade

Log into the VM through vagrant:

    $ vagrant ssh

Upgrade the OS and the tools:

    $ sudo aptitude update
    $ sudo aptitude dist-upgrade
    $ sudo mount /dev/scd0 /mnt
    $ sudo aptitude install build-essential linux-headers-$(uname -r)
    $ sudo /mnt/VBoxLinuxAdditions.run
    $ sudo rm -rf /usr/src/vboxguest*

insert whatever other upgrades you may need to do here.

    $ sudo aptitude purge build-essential linux-headers-$(uname -r)
    $ sudo aptitude clean
    $ sudo init 1

## Clean up

[http://dantwining.co.uk/2011/07/18/how-to-shrink-a-dynamically-expanding-guest-virtualbox-image/](http://dantwining.co.uk/2011/07/18/how-to-shrink-a-dynamically-expanding-guest-virtualbox-image/)

[“mount: / is busy” when trying to mount as read-only so that I can run zerofree.](http://unix.stackexchange.com/questions/42015/mount-is-busy-when-trying-to-mount-as-read-only-so-that-i-can-run-zerofree)

*Follow up*:
Following Jari's answer and [this post](https://forums.virtualbox.org/viewtopic.php?f=6&p=106422#p145104) by running these commands resolves the issue.

    $ service rsyslog stop
    $ service network-manager stop
    $ killall dhclient

Re-log through the console and execute:

    $ rm -r /var/cache/**/**
    $ mount -o remount,ro /dev/sda1
    $ zerofree /dev/sda1
    $ halt

Package the VM:

    $ cd /tmp/upgrade
    $ vagrant package
    $ vagrant box remove squeeze64
    $ vagrant box add squeeze64 /tmp/upgrade/package.box

Destroy the upgrade environment:

    $ cd /tmp/upgrade
    $ vagrant destroy

### Our home puppet (we compatible >= 2.7.19)

[http://docs.puppetlabs.com/guides/puppetlabs\_package\_repositories.html#for-debian-and-ubuntu](http://docs.puppetlabs.com/guides/puppetlabs_package_repositories.html#for-debian-and-ubuntu)

Latest 2.7 version:

    $ wget https://apt.puppetlabs.com/puppetlabs-release-precise.deb
    $ sudo dpkg -i puppetlabs-release-precise.deb
    $ sudo apt-get update

    $ sudo apt-get install puppet=2.7.25-1puppetlabs1 puppet-common=2.7.25-1puppetlabs1 facter=1.7.5-1puppetlabs1
