# Onenet complete solution Wiki

## Connectors log collection

The logs from the remote connectors are collected and stored in our Elastic stack

### Flow

The optimal way to do this would be from a Filebeat instance in each connector to our Logstash.
However this is not possible because Filebeat uses TCP connection which cannot pass through the company's
infrastructure.

This is solved by using an additional Logstash instance to each connector, and use HTTP output plugin
to HTTP input plugin. The flow becomes as below:

Connector logs -> Filebeat -> Logstash out -> Logstash in -> Elastic search

<img height="400" src="wiki/log collection flow2.png" width="800"/>

### Security

Logstash HTTP input and output plugin provide setup for certificates and option for strong Peer Verification.

This can be tested by deploying two Logstash instances inside a Docker network and setting up the certificates.

However this is not possible to implement in Ubitech's infrastructure as the HA proxy intervenes in
the connection and providing the domain name and proxying/forwarding to the Onenet VM. The connection
to domain is secure since it is protected by simple website encryption, but the certificate is not "carried" to the VM
so the Logstash in cannot perform the verification.

Still the connection is encrypted over the internet since its an HTTPS domain, and also
simple username password protection is enabled for the logstash instances.

See diagram below:

<img height="600" src="wiki/log to log security.png" width="1000"/>


#### Certificate creation and setup

As explained above, the certificates will not be used now but code and configuration is left commented out
intentionally.

This is a guide to generate working certificates/keys for secure communication.

Follow the guide on https://www.linode.com/docs/guides/secure-logstash-connections-using-ssl-certificates/ and run the commands as below

**NOTE** For `Common Name` or `CN` set the domain name where the receive Logstash is hosted. eg

- If its standalone set: `localhost`
- If its in Docker network, set the container name eg: `rec-logstash`
- If its in production server, set the domain name eg: `logstash-onenet.euprojects.eu`

_maybe we can use a wildcard_

```shell
sudo openssl genrsa -out /etc/pki/tls/private/org_ca.key 2048
sudo openssl req -x509 -new -nodes -key /etc/pki/tls/private/org_ca.key -sha256 -days 3650 -out /etc/pki/tls/private/org_ca.crt
sudo openssl genrsa -out /etc/pki/tls/private/logstash.key 2048
sudo openssl req -sha512 -days 3650 -new -key /etc/pki/tls/private/logstash.key -out logstash.csr
sudo chmod o+w /etc/pki/tls/private/ && sudo chmod o+w /etc/pki/tls/certs/
sudo openssl x509 -in /etc/pki/tls/private/org_ca.crt -text -noout -serial | tail -1 | cut -d'=' -f2 > /etc/pki/tls/private/org_ca.serial
sudo openssl x509 -days 3650 -req -sha512 -in logstash.csr -CAserial /etc/pki/tls/private/org_ca.serial -CA /etc/pki/tls/private/org_ca.crt -CAkey /etc/pki/tls/private/org_ca.key -out /etc/pki/tls/certs/org_logstash.crt -extensions v3_req
sudo cat /etc/pki/tls/certs/org_logstash.crt /etc/pki/tls/private/org_ca.crt > /etc/pki/tls/certs/logstash_combined.crt
sudo mv /etc/pki/tls/private/logstash.key /etc/pki/tls/private/logstash.key.pem
sudo chmod g+r /etc/pki/tls/private/logstash.key.pem
sudo openssl pkcs8 -in /etc/pki/tls/private/logstash.key.pem -topk8 -nocrypt -out /etc/pki/tls/private/logstash.key

sudo openssl genrsa -out /etc/pki/tls/private/client.key 2048
sudo openssl req -sha512 -new -key /etc/pki/tls/private/client.key -out client.csr
sudo openssl x509 -days 3650 -req -sha512 -in client.csr -CAserial /etc/pki/tls/private/org_ca.serial -CA /etc/pki/tls/private/org_ca.crt -CAkey /etc/pki/tls/private/org_ca.key -out /etc/pki/tls/certs/client.crt -extensions v3_req -extensions usr_cert
sudo cat /etc/pki/tls/certs/client.crt /etc/pki/tls/private/org_ca.crt > /etc/pki/tls/certs/client_combined.crt
sudo chmod o+r /etc/pki/tls/private/client.key
sudo cp /etc/pki/tls/private/client.key /etc/pki/tls/private/client.key.pem
sudo chmod g+r /etc/pki/tls/private/client.key.pem
sudo openssl pkcs8 -in /etc/pki/tls/private/client.key.pem -topk8 -nocrypt -out /etc/pki/tls/private/client.pkcs8.key
```

And set the plugins conf pipeline settings as below, with the appropriate url (domain, or container name)

```shell
output {
    http {
        url => "https://rec_logstash:5040"
        http_method => post
        cacert => '/etc/logstash/config/certs/org_logstash.crt'
        client_cert => '/etc/logstash/config/certs/client_combined.crt'
        client_key => '/etc/logstash/config/certs/client.pkcs8.key'
    }
}
```
```shell
input {
    http {
    port => 5040
    ssl => true
    ssl_certificate => '/etc/logstash/config/certs/logstash_combined.crt'
    ssl_key => '/etc/logstash/config/certs/logstash.key'
    ssl_certificate_authorities => ["/etc/logstash/config/certs/org_ca.crt"]
    ssl_verify_mode => "force_peer"
  }
}
```

It can also be tested by `curl` by:

`curl -d '{"message":"did it arrive?"}' --cacert certs/cert-with-onenet/org_logstash.crt --cert certs/cert-with-onenet/client_combined.crt --key certs/cert-with-onenet/client.key https://onenet-logstash.euprojects.net`
