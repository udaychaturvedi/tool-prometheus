#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y wget curl tar jq python3 python3-apt

# Create users & directories
useradd --no-create-home --shell /usr/sbin/nologin prometheus || true
mkdir -p /etc/prometheus /var/lib/prometheus

useradd --no-create-home --shell /usr/sbin/nologin grafana || true
mkdir -p /etc/grafana /var/lib/grafana

useradd --no-create-home --shell /usr/sbin/nologin alertmanager || true
mkdir -p /etc/alertmanager /var/lib/alertmanager

# (Node Exporter will be installed by Ansible role - avoid duplicate installs here)
