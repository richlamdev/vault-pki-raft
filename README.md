# HashiCorp Vault PKI with Raft backend

* [Introduction](#introduction)
* [Purpose](#purpose)
* [Prerequisites](#prerequisites)
   * [Knowledge](#knowledge)
   * [Software](#software)


## Introduction

This repo demonstrates [HashiCorp's Vault](https://www.hashicorp.com/products/vault)
product as a Certificate Authority (CA) for Public Key Infrastructure (PKI).
This demo utilizes a raft as a [storage backend](https://www.vaultproject.io/docs/configuration/storage) 
as opposed to a file backend which is typical in many demos/tutorials.
Deploying a raft configuration allows for convenient backup and recovery of data via
built-in commands.


## Purpose

The primary purpose is to provide a development/test environment to learn PKI with HashiCorp Vault.

This repo (platform) could potentially be used for personal/private networks, if you accept
the shortcomings.  The limitations are the lack comprehensive features and proper deployment
of HashiCorp raft backend infrastructure.


## Prerequisites

### Operating System & Shell

1. Developed on Ubuntu Linux 22.04 LTS.
2. Tested with Bash Shell

Naturally this repo will work with other \*nix Operating Systems and/or Shells with modification.

### Software

1. [HashiCorp Vault](https://www.vaultproject.io/downloads)
2. [Jq](https://stedolan.github.io/jq/download/)
3. [OpenSSL](https://wiki.openssl.org/index.php/Binaries)

### Optional, but preferred - this enables convenient copy and paste of login token
4. [xclip](https://github.com/astrand/xclip)

### Knowledge

1. Basic understanding of TLS certificates.  If knowledge is limited, then this is the perfect
   platform to learn and play with certificates to gain a better understanding.

2. Basic understanding of [HashiCorp Vault](https://www.vaultproject.io/).


## Quick Start

Clone the Repo:
```git clone https://github.com/richlamdev/vault-pki-raft.git```\
```cd vault-pki-raft```\

Steps:
```./raft start```\
```./create_root_inter_certs.sh```\
```./issue_cert_template.sh```

The above will perform the following:
1. Deploy a single Vault instance with a raft backend. - [raft.sh]

2. Enable Vault PKI Engine / create a Certificate Authority (CA) - [create_root_inter_certs.sh]
    a. Create root certificate and self sign the certificate.\
       The root CA is designated by the variable ISSUER_NAME_CN.
       For the purposes of this demo, the ISSUER_NAME_CN is "Lord of the Rings".

    b. Create intermediate certificate signing request, have the root authority sign
       this certificate and store it within the CA.

    c. Create a role to sign leaf certificates.  This role is authorized to
       sign subdomains as designate by the variable assigned in VAULT_ROLE.
       In this case, the role is authorized to sign subdomains of "middleearth.test".

    d. The self-signed CA root certificate and intermediate certificate chain are stored
       in the directory as designated by the variable $ROOT_INTER_DIR.  The directory is set
       to "./root_inter_certs".

3. Issue a \"template\" certificate with a Common Name (CN) ```template.middleearth.test``` - [issue_cert_template.sh]



### References
[HashiCorp Storage Backend](https://www.vaultproject.io/docs/configuration/storage)\
[HashiCorp Vault Backup](https://learn.hashicorp.com/tutorials/vault/sop-backup)\
[HashiCorp Vault Restore](https://learn.hashicorp.com/tutorials/vault/sop-restore)\

[smallstep PKI article](https://smallstep.com/blog/everything-pki/)
