---
layout: post
title: How to rebuild ubuntu memcached package from bzr source to lift up upstream version
---

Read Manual at [Ubuntu Packaging Guide](http://packaging.ubuntu.com/html/index.html)

### Install dev environment

[Getting set up instructions](http://packaging.ubuntu.com/html/getting-set-up.html)

There are a number of tools that will make your life as an Ubuntu developer much easier. You will encounter these tools later in this guide. To install most of the tools you will need run this command:

    $ sudo apt-get install gnupg pbuilder ubuntu-dev-tools bzr-builddeb apt-file

Note: Since Ubuntu 11.10 “Oneiric Ocelot” (or if you have Backports enabled on a currently supported release), the following command will install the above and other tools which are quite common in Ubuntu development:

    $ sudo apt-get install packaging-dev

Set up pbuilder environment

    $ pbuilder-dist <release> create

### Create your GPG/SSH keys

    $ gpg --gen-key
    $ ssh-keygen -t rsa

### Upload your GPG/SSH pub keys to Launchpad

To find about your GPG fingerprint, run:

    $ gpg --fingerprint email@address.com

and it will print out something like:

    pub   4096R/43CDE61D 2010-12-06
          Key fingerprint = 5C28 0144 FB08 91C0 2CF3  37AC 6F0B F90F 43CD E61D
    uid   Daniel Holbach <dh@mailempfang.de>
    sub   4096R/51FBE68C 2010-12-06

Then run this command to submit your key to Ubuntu keyserver:

    $ gpg --keyserver keyserver.ubuntu.com --send-keys 43CDE61D

where `43CDE61D` should be replaced by your key ID (which is in the first line of output of the previous command). Now you can import your key to Launchpad.

### Upload your SSH key to Launchpad

Configure Bazaar

    $ bzr whoami "Bob Dobbs <subgenius@example.com>"
    $ bzr launchpad-login subgenius

Configure your shell¶

    export DEBFULLNAME="Bob Dobbs"
    export DEBEMAIL="subgenius@example.com"

Fix pbuilder-dist distribution bug under precise [https://bugs.launchpad.net/ubuntu/+source/ubuntu-dev-tools/+bug/1068390](https://bugs.launchpad.net/ubuntu/+source/ubuntu-dev-tools/+bug/1068390)

{% highlight bash %}
pbuilder-dist quantal update
Traceback (most recent call last):
  File "/usr/bin/pbuilder-dist", line 462, in <module>
    main()
  File "/usr/bin/pbuilder-dist", line 456, in main
    sys.exit(subprocess.call(app.get_command(args)))
  File "/usr/bin/pbuilder-dist", line 286, in get_command
    if self.target_distro == UbuntuDistroInfo().devel():
  File "/usr/lib/python2.7/dist-packages/distro_info.py", line 92, in devel
    raise DistroDataOutdated()
distro_info.DistroDataOutdated: Distribution data outdated
{% endhighlight %}

_WORKAROUND:_

In Precise, a quick and dirty fix is to edit the file `/usr/bin/pbuilder-dist` , commenting out lines 286 to 289 by prefixing each line with a #.

### Pull source

[http://packaging.ubuntu.com/html/udd-getting-the-source.html](http://packaging.ubuntu.com/html/udd-getting-the-source.html)

    $ bzr init-repo memcached
    $ cd memcached
    $ bzr branch ubuntu:precise/memcached memcached.dev
    $ cd memcached.dev

If you've got something like `bzr: ERROR: Revision {package-import@ubuntu.com-*}
not present in "Graph(StackedParentsProvider(bzrlib.repository._LazyListJoin(([CachingParentsProvider(None)], []))))"`
on branching bzr request, use: `-Olaunchpad.packaging_verbosity=off` to mitigate the
[issue](https://bugs.launchpad.net/bzr/+bug/888615).

### Working on package

[http://packaging.ubuntu.com/html/udd-working.html](http://packaging.ubuntu.com/html/udd-working.html)

Make working copy of upstream branch

    $ bzr branch memcached.dev 1.4.18-0ubuntu1
    $ cd 1.4.18-0ubuntu1

Update source files.

Fix debian/watch:

    version=3
    opts=\
    downloadurlmangle=s|.*[?]name=(.*?)&.*|http://www.memcached.org/files/$1|,\
    filenamemangle=s|[^/]+[?]name=(.*?)&.*|$1| \
    http://www.memcached.org/files/memcached-([0-9.]+).tar.gz.*

Remove old patch `debian/patches/60_fix_racey_test.patch` 

Fix `series` file

Regenerate `configure`

Update doc/Makefile

### Commit changes

    $ bzr st
    $ bzr add ...
    $ dch -i
    $ bzr commit

A hook in `bzr-builddeb` will use the `debian/changelog` text as the commit message and set the tag to mark bug _#12345_ as fixed.

This only works with `bzr-builddeb 2.7.5` and `bzr 2.4`, for older versions use `debcommit`.

### Rebuild package

    $ bzr builddeb -S
    $ pbuilder-dist precise build ../memcached_1.4.18-0ubuntu1.dsc

You can test new package. It can be found at

    $ dpkg -I ~/pbuilder/*_result/memcached_*.deb

### Push update into launchpad

To push it to Launchpad, as the remote branch name, you need to stick to the following nomenclature:

    lp:~<yourlpid>/ubuntu/<release>/<package>/<branchname>

This could for example be:

    lp:~john-koepi/ubuntu/precise/memcached/memcached.dev

or

    lp:~john-koepi/ubuntu/precise/memcached/default

So if you just run:

    $ bzr push lp:~john-koepi/ubuntu/precise/memcached/default

### Uploading packages to this PPA

You can upload packages to this PPA using:

    $ dput ppa:john-koepi/common <source.changes>

### Multi-distribution PPA upload path

[Support new multi-distribution PPA upload path](https://bugs.launchpad.net/ubuntu/+source/dput/+bug/1340130)

Since http://bazaar.launchpad.net/+branch/launchpad/revision/17093, 
Launchpad has supported a new form for the PPA upload path, 
~<person>/<distro>/<ppa>. </ppa></distro></person>

[PPA & Packaging: Having versions of packages for multiple distros](http://askubuntu.com/questions/30145/ppa-packaging-having-versions-of-packages-for-multiple-distros)

Probably the easiest way is to simply copy the binaries on Launchpad or
use another name.

For example:

    nginx (1:1.4.1-0ubuntu1~preciseppa1) precise; urgency=low

`bzr builddeb -S` strips last suffix from debian/changelog version to match local
version to watched. To match memcached `watch` file you should use:

    memcached (1.4.20-0precise1) precise; urgency=low

Whether to use debuild -S -sd or debuild -S -sa is really a different question,
but here’s a brief answer.

-sa ensures that the .orig.tar.bz2 will be uploaded. If you haven’t made an
upload of this upstream version before, use this.

-sd explicitly makes it so that only the debian.tar.gz or diff.tar.gz are uploaded.
This is for when you are making a change to an upstream version that is already
available in you target archive or PPA. This is because th original tarball
should already be present there.
