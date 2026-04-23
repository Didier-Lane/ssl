# SSL

Generates self-signed [ECDSA] certificates with [openssl]

## Trust a self-signed CA certificate

<details>
<summary>Debian / Ubuntu</summary>

```shell
sudo cp CA.crt /usr/local/share/ca-certificates
sudo update-ca-certificates
```

</details>

<details>
<summary>Fedora / Arch</summary>

```shell
sudo trust anchor --store CA.crt
sudo update-ca-trust
```

</details>

[openssl]: https://www.openssl.org/
[ECDSA]: https://www.rfc-editor.org/rfc/rfc8446#section-1

TODO trusted ?
openssl x509 -in ~/.ssl/local.io/nginx/nginx.crt -trustout -out test.crt

### Removing

```shell
sudo trust list | grep -C 5 Didier

sudo trust anchor --remove "pkcs11:id=..;type=cert"
sudo update-ca-trust
```
