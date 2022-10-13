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

The primary purpose is to a development/test environment to learn PKI with HashiCorp Vault.

This platform could potentially be used for personal/private networks, if you accept
the shortcomings.  The shortcomings would primarily be the lack comprehensive features,
and proper deployment of HashiCorp raft backend infrastructure.



## Prerequisites

### Operating System & Shell

1. Developed on Ubuntu Linux 22.04 LTS.
2. Tested with Bash Shell

Naturally this repo will work with other \*nix Operating Systems and/or Shells with testing
or modification.

### Software

1. [HashiCorp Vault](https://www.vaultproject.io/downloads)
2. [Jq](https://stedolan.github.io/jq/download/)
3. [OpenSSL](https://wiki.openssl.org/index.php/Binaries)

### Optional, but preferred
4. [xclip](https://github.com/astrand/xclip)


## Quick Start

Clone the Repo:
```git clone https://github.com/richlamdev/vault-pki-raft.git```\
```cd vault-pki-raft```\

Steps:
```./raft start```\
```./create_root_inter_certs.sh```\
```./issue_cert_template.sh```

The above will perform the following:
1. Deploy a single Vault instance with a raft backend
2. Enable Vault PKI Engine / create a Certificate Authority (CA)
    1. Create root certificate and self sign this certificate.\
       This demo names the root CA as "Lord of the Rings"
    2. Create intermediate certificate signing request, have the root authority sign
       this certificate and store it within the CA.
    3. Create a role to sign leaf certificates.  This role is authorized to
       sign subdomains of middleearth.test.
3. Issue a \"template\" certificate with a Common Name (CN) ```template.middleearth.test```


