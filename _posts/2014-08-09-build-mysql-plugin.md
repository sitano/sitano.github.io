---
layout: post
title: How to build custom plugin (SphinxCE) for Percona MySQL
---

#### Preparation

    sudo apt-get install dh-autoreconf libcrypto++-dev libssl-dev

#### Dependencies

    sudo apt-get install dpkg-dev cmake libaio-dev libncurses5-dev bison

#### Get sources for required MySQL version

    sudo apt-get source percona-server-server-5.5

[Percona Server 5.5 Sources](http://www.percona.com/downloads/Percona-Server-5.5/).

[Percona Server 5.6 Sources](http://www.percona.com/downloads/Percona-Server-5.6/).

#### Prebuild MySQL sources

    cd percona-server-5.5-5.5.29-rel29.4
    cp -R /usr/src/sphinx-2.0.6-release/mysqlse/ ./storage/sphinx/
    /bin/rm -rf CMakeCache.txt CMakeFiles/
    . ./BUILD/autorun.sh
    cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_CONFIG=mysql_release -DFEATURE_SET=community -DWITH_EMBEDDED_SERVER=OFF

#### Build plugin

    cd storage/sphinx/ && make

#### Install plugin

    cp ha_sphinx.so /usr/lib/mysql/plugin/
    chmod 644 /usr/lib/mysql/plugin/ha_sphinx.so
    INSTALL PLUGIN sphinx SONAME 'ha_sphinx.so';
    SHOW engines
