---
layout: post
title: Long wait time on ssh login
---

Trying to figure out reason for long logins on our database production servers.
We have Ubuntu 12.04 LTS installed and not so many iops during login sessions.

### Source

* [http://injustfiveminutes.com/2013/03/13/fixing-ssh-login-long-delay/](http://injustfiveminutes.com/2013/03/13/fixing-ssh-login-long-delay/)
* [http://askubuntu.com/questions/11538/long-wait-time-on-login](http://askubuntu.com/questions/11538/long-wait-time-on-login)

### 1. Disable reverse IP resolution on SSH server

It turns out there is a setting in OpenSSH that controls whether 
SSHd should not only resolve remote host names but also check 
whether the resolved host names map back to remote IPs. Apparently, 
that setting is enabled by default in OpenSSH. The directive UseDNS 
controls this particular behaviour of OpenSSH, and while it is 
commented in sshd_config (which is the default configuration file 
for the OpenSSH daemon in most enviornments), as per the man page 
for sshd_config, the default for UseDNS is set to enabled. 
Add the following line:

    UseDNS no

### 2. DNS resolver fix for IPv4/IPv6 enabled stacks

It’s a known issue on the Red Hat knowledgebase article 
[DOC-58626](https://access.redhat.com/kb/docs/DOC-58626), 
but since it’s closed without login, I’ll share the solution below:

    The resolver uses the same socket for the A and AAAA requests. 
    Some hardware mistakenly only sends back one reply. When that happens 
    the client sytem will sit and wait for the second reply. Turning this 
    option on changes this behavior so that if two requests from the 
    same port are not handled correctly it will close the socket and 
    open a new one before sending the second request.

The solution is to add the following line to your `/etc/resolv.conf`. 
Just add it all the way at the bottom, as the last line.

    options single-request-reopen

### 3. Disable GSSAPI authentication method

OpenSSH server enables by default the GSSAPI key exchange which 
allows you to leverage an existing key management infrastructure 
such as Kerberos or GSI, instead of having to distribute ssh host 
keys throughout your organisation. With GSSAPI key exchange servers 
do not need ssh host keys when being accessed by clients with valid 
credentials.

If you are not using GSSAPI as a authentication mecanism, 
it might be causing this connection delay.

The fix is simple – disable attempts to use GSS-API by adding 
the following to `/etc/sshd_config` (server side) or your 
`~/.ssh/ssh_config` (client side).

    GSSAPIAuthentication no

There is an easy way to check beforehand whether this solution will 
work. Try to ssh into your server by disabling GSSAPI authentication:

    ssh -o GSSAPIAuthentication=no user@yourserver

### 4. `pam_motd` problem

Disable `pam_motd` in the following files:

    /etc/pam.d/sshd
    /etc/pam.d/login

One more:

    apt-get purge landscape-client landscape-common

delete the contents of the /etc/update-motd.d directory.

chmod -x the scripts in /etc/update-motd.d that you don’t want to run.

Bug report on this issue:

* [https://bugs.launchpad.net/ubuntu/+source/pam/+bug/805423](https://bugs.launchpad.net/ubuntu/+source/pam/+bug/805423)

