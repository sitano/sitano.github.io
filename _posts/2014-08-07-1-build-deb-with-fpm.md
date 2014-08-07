---
layout: post
title: How to easily build deb package with FPM
---

### What is [FPM](https://github.com/jordansissel/fpm)?

Effing package management! Build packages for multiple platforms (deb, rpm, etc) with great ease and sanity.

### Install [FPM](https://github.com/jordansissel/fpm)

    sudo apt-get install make ruby ruby-dev dpkg-dev
    sudo gem install fpm

### Build package

    fpm -s dir -t deb -n <NAME> -v 1.0 <DIR>

### Update repository package indexes

    dpkg-scanpackages . /dev/null | gzip -c9 > Packages.gz
