---
layout: post
title: How to build Percona MySQL Server 5.5 from SOURCE
---

* [Official old documentation](http://www.percona.com/doc/percona-server/5.5/installation.html?id=percona-server:installation:from-repositories#installing-percona-server-from-a-source-tarball)
* [PPA for Ubuntu Toolchain Uploads (restricted) team](https://launchpad.net/~ubuntu-toolchain-r/+archive/test|https://launchpad.net/~ubuntu-toolchain-r/+archive/test)

### Introduction

A lot of work was done before found out there is one OPTION that handles pthread mutex spin optimization
through redefining macros definitions of basic implementation. Changing this option for build breaks backward
binary compatibility of plugins built with old value.

#### How to build RELEASE official way

    $ sudo apt-get install dh-autoreconf libcrypto++-dev libssl-dev
    $ sudo apt-get install dpkg-dev cmake libaio-dev libncurses5-dev bison
    $ ./build-ps/build-binary.sh

#### How to build RELEASE by hands

    $ sudo apt-get install dh-autoreconf libcrypto++-dev libssl-dev
    $ sudo apt-get install dpkg-dev cmake libaio-dev libncurses5-dev bison
    $ cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_CONFIG=mysql_release -DFEATURE_SET=community -DWITH_EMBEDDED_SERVER=OFF

Now, compile using make.

    $ make

Install:

    $ make install

#### How to build FULL_DEBUG

    $ sudo apt-get install dh-autoreconf libcrypto++-dev libssl-dev
    $ sudo apt-get install dpkg-dev cmake libaio-dev libncurses5-dev bison

##### Fix ./build-ps/build-binary.sh:

Add in --debug section:

    CMAKE_OPTS="${CMAKE_OPTS:-} -DWITH_DEBUG=ON"

Change `-DWITH_PAM=ON` do `-DWITH_PAM=OFF` (if you don't want a PAM)

Fix make * install if you do not want it to exec automatically.

Build:

    $ ./build-ps/build-binary.sh --debug .

If you have got warnings as errors:

Remove -Werror flags from CMakeCache.txt or add right after -Wno-error

Build:

    $ ./build-ps/build-binary.sh --debug .

Then:

    $ sudo apt-get install checkinstall
    $ sudo checkinstall make install

### Installing Percona Server from the Bazaar Source Tree

[Installing Percona Server from the Bazaar Source Tree](http://www.percona.com/doc/percona-server/5.5/installation.html#installing-percona-server-from-the-bazaar-source-tree)

Percona uses the [Bazaar|http://bazaar.canonical.com/en/] revision control system for development.

To build the latest Percona Server from the source tree you will need Bazaar installed on your system.

Good practice is to use a shared repository, create one like this:

    $ bzr init-repo ~/percona-server

You can now fetch the latest Percona Server 5.5 sources. In the future, we will provide instructions for fetching each specific Percona Server version and building it, but currently we will just talk about building the latest Percona Server 5.5 development tree.

    $ cd ~/percona-server
    $ bzr branch lp:percona-server/5.5

Fetching all the history of Percona Server 5.5 may take a long time, up to 20 or 30 minutes is not uncommon.

If you are going to be making changes to Percona Server 5.5 and wanting to distribute the resulting work, you can generate a new source tarball (exactly the same way as we do for release):

    $ cmake .
    $ make dist

Next, follow the instructions in [Compiling Percona Server from Source](http://www.percona.com/doc/percona-server/5.5/installation.html#compile-from-source) below.

### Compiling Percona Server from Source

[Compiling Percona Server from Source](http://www.percona.com/doc/percona-server/5.5/installation.html#compiling-percona-server-from-source)

After either fetching the source repository or extracting a source tarball (from Percona or one you generated yourself), you will now need to configure and build Percona Server.

First, run cmake to configure the build. Here you can specify all the normal build options as you do for a normal _MySQL_ build. Depending on what options you wish to compile Percona Server with, you may need other libraries installed on your system. Here is an example using a configure line similar to the options that Percona uses to produce binaries:

    $ cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_CONFIG=mysql_release -DFEATURE_SET=community -DWITH_EMBEDDED_SERVER=OFF

Now, compile using make

    $ make

Install:

    $ make install

Percona Server 5.5 will now be installed on your system.

### Building Percona Server Debian/Ubuntu packages

[Building Percona Server Debian/Ubuntu packages](http://www.percona.com/doc/percona-server/5.5/installation.html#building-percona-server-debian-ubuntu-packages)

If you wish to build your own Percona Server Debian/Ubuntu (dpkg) packages, you first need to start with a source tarball, either from the Percona website or by generating your own by following the instructions above ([Installing Percona Server from the Bazaar Source Tree](http://www.percona.com/doc/percona-server/5.5/installation.html#source-from-bzr)).

Extract the source tarball:

    $ tar xfz percona-server-5.5.34-32.0.tar.gz
    $ cd percona-server-5.5.34-32.0

Put the debian packaging in the directory that Debian expects it to be in:

    $ cp -ap build-ps/debian debian

Update the changelog for your distribution (here we update for the unstable distribution - sid), setting the version number appropriately. The trailing one in the version number is the revision of the Debian packaging.

    $ dch -D unstable --force-distribution -v "5.5.34-32.0-1" "Update to 5.5.34-32.0"

Build the Debian source package:

    $ dpkg-buildpackage -S

Use sbuild to build the binary package in a chroot:

    $ sbuild -d sid percona-server-5.5_5.5.34_32.0-1.dsc

You can give different distribution options to dch and sbuild to build binary packages for all Debian and Ubuntu releases.

#### Note

[PAM Authentication Plugin](http://www.percona.com/doc/percona-server/5.5/management/pam_plugin.html#pam-plugin) has been merged into Percona Server in [5.5.24-26.0](http://www.percona.com/doc/percona-server/5.5/release-notes/Percona-Server-5.5.24-26.0.html#5.5.24-26.0) but it is not built with the server by default. In order to build the Percona Server with PAM plugin, additional option -DWITH_PAM=ON should be used.
