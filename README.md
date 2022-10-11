# HashiCorp Vault PKI with Raft backend

* [Introduction](#introduction)
* [Purpose](#purpose)
* [Prerequisites](#prerequisites)
   * [Knowledge](#knowledge)
   * [Software](#software)


## Introduction

This repo demonstrates [HashiCorp's Vault](https://www.hashicorp.com/products/vault)
product as a Certificate Authority (CA) for Public Key Infrastructure (PKI).
This demo utilizes a raft as a storage backend for convenient backup and restoration.


## Purpose

The primary purpose is to a development/test environment to learn PKI with HashiCorp Vault.

This platform could potentially be used for personal/private networks, if you accept
the shortcomings.  The shortcomings would primarily be the lack comprehensive features,
and proper setup of raft backend.


## Prerequisites

### Operating System & Shell

This was developed on Ubuntu Linux 22.04 LTS with BASH as the shell.

### Software

1. [HashiCorp Vault](https://www.vaultproject.io/downloads)
2. [Jq](https://stedolan.github.io/jq/download/)
3. [OpenSSL](https://wiki.openssl.org/index.php/Binaries)

### Optional, but preferred
4. [xclip](https://github.com/astrand/xclip)


