# SSL

Generates self-signed [ECDSA] certificates with [openssl]

## Requirements

- [openssl]
- [GNU Make](https://www.gnu.org/software/make/)

## Usage

Operations are organized as make recipes, just run `make` to see the list of available targets.

```shell
$ make
Usage

# To run and execute a target
make <target>

Available Targets

~/.ssl/%/CA.crt     📜 Generates a self-signed certification authority certificate
~/.ssl/%.crt        📜 Generates a self-signed certificate
help                💡 Shows this help menu
clean               ✨ Cleans the working copy
```

## Key principles

This project provides two make targets for generating either a single [Certification Authority (CA)](#certification-authority) certificate or both a [CA](#certification-authority) and a [certificate](#certificate).

>[!NOTE]
>Thoses targets names depends on the value of the `SSL_DIR` [environment variable][environment variables], which by default is `~/.ssl`.

### Certification Authority

The `~/.ssl/%/CA.crt` target generates a self-signed CA certificate, it constraints the generated certificate filename to be `CA.crt` by design.

By default the Common name of the generated CA certificate is the name of the directory, this can be defined with the `CA_COMMON_NAME` [command line argument].

### Certificate

The `~/.ssl/%.crt` target generates a self-signed certificate, it constraints the generated certificate filename to be ending by `.crt` by design.

By default the Common name of the generated certificate is the name of the certificate file, this can be defined with the `COMMON_NAME` [command line argument].

This recipe also generates a [Certification Authority (CA)](#certification-authority) certificate if none were provided with the `CERT_AUTHORITY` [command line argument].

### Signature algorithms

This project focuses only on the following [TLS 1.3 signature algorithms] :

- ecdsa_secp256r1_sha256
- ecdsa_secp384r1_sha384

The `ecdsa_secp384r1_sha384` signature algorithm is used by default, unless overriden through [command line arguments].

### The `.env` file

The `.env` file holds persisted [environment variables], it is automatically created on each invocation of `make`.

It can be removed either manually or with the `make clean` command.

### Environment variables

Those are the variables being persisted to the [`.env`] file when running `make`

| Name                  | Aliases                       | Description                                           | Default value
|:--                    |:--                            |:--                                                    |:--
| `SSL_DIR`             |                               | The root directory were certificates will be created  | `~/.ssl`
| `REQ_DAYS`            | `DAYS`, `D`                   | The number of days to certify the certificate         | `3560`
| `COUNTRY`             | `CT`, `C`                     | The Country name of the certificate                   | `FR`
| `STATE`               | `ST`, `S`                     | The State or Province name of the certificate         | `Paris`
| `LOCALITY`            | `LO`, `L`                     | The Locality name of the certificate                  | `Paris`
| `ORGANIZATION`        | `OG`, `O`                     | The Organization name of the certificate              | `Local`
| `ORGANIZATION_UNIT`   | `OU`, `U`                     | The Organization Unit name of the certificate         | `IT`

>[!TIP]
>Environment variables can be overriden through [command line arguments] when invoking `make`

### Command line arguments

| Name                  | Aliases                       | Description
|:--                    |:--                            |:--
| `ALGORITHM`           | `ALG`, `A`                    | The [signature algorithm] to use
| `COMMON_NAME`         | `CNAME`, `CN`                 | The Common name of the generated certificate
| `SUBJECT_ALT_NAMES`   | `ALT_NAMES`, `SAN`            | The Subject Alternative Names of the generated certificate
| `CA_COMMON_NAME`      | `CA_NAME`, `CA_CN`            | The Common name of the generated CA certificate
| `CERT_AUTHORITY`      | `AUTHORITY`, `CA`             | The CA certificate used to sign the generated certificate
| `DRY_RUN`             | `DRY`                         | Toggles dry run by just printing informations

## Examples

### Dry run

>To just print informations run with `DRY_RUN=1` or `DRY=1`
```shell
$ make ~/.ssl/test/test.crt DRY_RUN=1
```

### Generate a CA certificate

>To generate a CA certificate in the `~/.ssl/test` folder with `test` as Common name
```shell
$ make ~/.ssl/test/CA.crt
```

>To generate a CA certificate in the `~/.ssl/test` folder with `Test CA` as Common name
```shell
$ make ~/.ssl/test/CA.crt CA_COMMON_NAME="Test CA"
```

### Generate both CA and certificate

>To generate a CA certificate in the `~/.ssl/test` folder with `Test CA` as Common name
>and a certificate in the `~/.ssl/test` folder with `Test` as Common name
```shell
$ make ~/.ssl/test/test.crt CA_COMMON_NAME="Test CA" COMMON_NAME="Test"
```

### Generate a certificate with subject alternative names

>To generate a CA certificate in the `~/.ssl/test` folder with `Test CA` as Common name
>and a certificate in the `~/.ssl/test` folder with `Test` as Common name
>and `test.com *.test.com 127.0.0.1 ::1` as subject alternative names
```shell
$ make ~/.ssl/test/test.crt CA_COMMON_NAME="Test CA" COMMON_NAME="Test" SUBJECT_ALT_NAMES='test.com *.test.com 127.0.0.1 ::1'
```

### Generate a certificate from an existing CA

>To generate a certificate in the `~/.ssl/test` folder with `Test` as Common name
>signed by the CA located in `~/.ssl/foo/CA.crt`
```shell
$ make ~/.ssl/test/test.crt CERT_AUTHORITY=~/.ssl/foo/CA.crt COMMON_NAME="Test"
```

## Trust / untrust a self-signed CA certificate

### Add a CA certificate to the trust store

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

### Remove a CA certificate from the trust store

<details>
<summary>Debian / Ubuntu</summary>

```shell
sudo rm /usr/local/share/ca-certificates/CA.crt
sudo update-ca-certificates
```

</details>

<details>
<summary>Fedora / Arch</summary>

```shell
sudo trust list | grep -C 5 "CA certificate Common Name"
sudo trust anchor --remove "pkcs11:id=..;type=cert"
sudo update-ca-trust
```

</details>

[`.env`]: #the-env-file
[environment variables]: #environment-variables
[command line argument]: #command-line-arguments
[command line arguments]: #command-line-arguments
[openssl]: https://www.openssl.org/
[ECDSA]: https://www.rfc-editor.org/rfc/rfc8446#section-1
[TLS 1.3 signature algorithms]: https://www.rfc-editor.org/rfc/rfc8446#section-4.2.3
[signature algorithm]: #signature-algorithms
