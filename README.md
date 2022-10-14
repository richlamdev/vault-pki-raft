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

### Optional, but preferred - this enables convenient copy and paste of root token to login to Vault. (either CLI and/or GUI)
4. [xclip](https://github.com/astrand/xclip)

### Knowledge

1. Basic understanding of TLS certificates.  If knowledge is limited, then this 
   platform is great to learn and play with TLS certificates and Certificate Authority (CA)

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

2. Enable Vault PKI Engine / create a CA - [create_root_inter_certs.sh]\
    a. Create a root certificate and self sign the certificate.
       The root CA is designated by the variable ISSUER_NAME_CN.
       For the purposes of this demo, the ISSUER_NAME_CN is "Lord of the Rings".  Change this value as you like.\

    b. Create an intermediate certificate signing request, have the root authority sign
       this certificate and store it within the CA.

    c. Create a role designated by the variable VAULT_ROLE to sign leaf certificates.
       Note the value of VAULT_ROLE, itself, is not critical.  However, the VAULT_ROLE value
       must be the same in both files, create_root_inter_certs.sh and issue_cert_template.sh.  
       This role name is referenced (used) to sign leaf certificates.  If they do not match, an error will occur.
       Change this value as you like, just keep them consistent.
       VAULT_ROLE is authorized to sign subdomains indicated by the variable DOMAIN, 
       in this case the Second Level Domain (SLD) and Top Level Domain(TLD), combined is
       "middleearth.test".  Again, change this value as you like.

    d. The self-signed CA root certificate and intermediate certificate chain are stored
       in the directory as designated by the variable $ROOT_INTER_DIR.  The directory is set
       to "./root_inter_certs".

3. Issue a \"template\" certificate with a Subject Common Name (CN) ```template.middleearth.test``` - [issue_cert_template.sh]
    a. The resulting public certificate, key file, as well as entire signed json blob is stored in directory
       designated by the variable SUBJECT_CN.  Edit the HOST and DOMAIN variables to change the value of SUBJECT_CN.
       Ensure the value of DOMAIN is the same in both files, create_root_inter_certs.sh and issue_cert_template.sh.
       In this example, the resulting certificate files will be stored i nthe directory ```template.middleearth.test```



### References
[HashiCorp Storage Backend](https://www.vaultproject.io/docs/configuration/storage)\
[HashiCorp Vault Backup](https://learn.hashicorp.com/tutorials/vault/sop-backup)\
[HashiCorp Vault Restore](https://learn.hashicorp.com/tutorials/vault/sop-restore)\

[smallstep PKI article](https://smallstep.com/blog/everything-pki/)
