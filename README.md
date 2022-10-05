# HashiCorp Vault PKI with Raft backend

* [Introduction](#introduction)
* [Purpose](#purpose)
* [Prerequisites](#prerequisites)
   * [Knowledge](#knowledge)
   * [Software](#software)


## Introduction

This repo demonstrates [HashiCorp's Vault](https://www.hashicorp.com/products/vault) product as a Public Key Infrastructure (PKI)
aka Certificate Authority (CA) utilizing a raft as a storage backend.

## Purpose

The primary purpose is to a development/test environment to learn PKI with HashiCorp Vault.

This platform could potentially be used for personal/private networks, accepting
shortcomings of a comprehensive, always available, production ready PKI platform.

## Prerequisites

1. [HashiCorp Vault](https://www.vaultproject.io/downloads)
2. [Jq](https://stedolan.github.io/jq/download/)
3. [OpenSSL](https://wiki.openssl.org/index.php/Binaries)

### Optional, but preferred
4. [xclip](https://github.com/astrand/xclip)
