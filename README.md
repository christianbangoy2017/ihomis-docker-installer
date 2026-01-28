# iHOMIS Plus – Docker Installer

This repository provides a Docker-based initial installer for iHOMIS Plus.

## Scope
This installer includes:
- Apache + PHP 7.4 (Dockerized)
- HTTPS enabled (self-signed)
- MySQL 5.7
- Initial database schema and reference data (NO patient data)
- One-command restore/install script

## What this repository DOES NOT include
- Production patient data
- Database backups
- Operational backup scripts

After installation, system ownership and backups are handled by the hospital IT unit.

## Usage

```bash
./restore-ihomis.sh

