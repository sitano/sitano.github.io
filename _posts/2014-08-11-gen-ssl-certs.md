---
layout: post
title: NginX HttpSslModule Generate Certificates
---

## Generate Certificates

[http://wiki.nginx.org/HttpSslModule](http://wiki.nginx.org/HttpSslModule)
[http://nginx.org/en/docs/http/configuring\_https\_servers.html](http://nginx.org/en/docs/http/configuring_https_servers.html)

To generate private (dummy) certificates you can perform the following list of openssl commands.

First change directory to where you want to create the certificate and private key, for example:

    $ cd /usr/local/nginx/conf

Now create the server private key:

    $ openssl genrsa -out server.key 2048

You can also create a private key with a passphrase, but you will need to enter it every time you start nginx:

    $ openssl genrsa -des3 -out server.key 2048

Create the Certificate Signing Request (CSR):

    $ openssl req -new -key server.key -out server.csr

Finally sign the certificate using the above private key and CSR:

    $ openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

Update Nginx configuration by including the newly signed certificate and private key:

    server {
        server_name <YOUR_DOMAINNAME_HERE>;
        listen 443;
        ssl on;
        ssl_certificate /usr/local/nginx/conf/server.crt;
        ssl_certificate_key /usr/local/nginx/conf/server.key;
    }

Restart Nginx.

Now we're ready to access the above host using.
