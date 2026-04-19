# SSL

Generates self-signed [Ed25519] certificates with [openssl]

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
[Ed25519]: https://ed25519.cr.yp.to/
