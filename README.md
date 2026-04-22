# Dnsmasq + SNI Proxy One-click Install

## Overview

Uses [Dnsmasq](http://thekelleys.org.uk/dnsmasq/doc.html) to hijack DNS resolution for streaming domains and [SNI Proxy](https://github.com/dlundquist/sniproxy) to reverse-proxy the traffic. This allows a VPS that cannot access streaming services to proxy through one that can.

## Supported Systems

- CentOS 7+
- Debian 8+
- Ubuntu 16+

## Domain Profiles

Use `-p <profile>` to select which streaming services to unlock:

| Profile | Flag | Services |
|---------|------|----------|
| **all** (default) | `-p all` | Netflix, Hulu, HBO, Disney+, YouTube, etc. ([full list](proxy-domains.txt)) |
| **youtube** | `-p youtube` | YouTube only ([list](proxy-domains-youtube.txt)) |
| **disney** | `-p disney` | Disney+ only ([list](proxy-domains-disney.txt)) |

## Usage

```
bash dnsmasq_sniproxy.sh <action> [-p <profile>]
```

### Actions

| Flag | Description |
|------|-------------|
| `-i`, `--install` | Install Dnsmasq + SNI Proxy (compile from source) |
| `-f`, `--fastinstall` | Fast install (pre-built binaries) |
| `-id`, `--installdnsmasq` | Install Dnsmasq only |
| `-fd`, `--fastinstalldnsmasq` | Fast install Dnsmasq only |
| `-is`, `--installsniproxy` | Install SNI Proxy only |
| `-fs`, `--fastinstallsniproxy` | Fast install SNI Proxy only |
| `-r`, `--refresh` | Refresh domain lists (no reinstall) |
| `-u`, `--uninstall` | Uninstall Dnsmasq + SNI Proxy |
| `-ud`, `--undnsmasq` | Uninstall Dnsmasq |
| `-us`, `--unsniproxy` | Uninstall SNI Proxy |
| `-h`, `--help` | Show help |

## Quick Install Examples

### Fast install - all streaming services (default):
```bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -f
```

### Fast install - YouTube only:
```bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -f -p youtube
```

### Fast install - Disney+ only:
```bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -f -p disney
```

### Compile install (builds dnsmasq 2.91 + sniproxy 0.6.1 from source):
```bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -i
```

### Uninstall:
```bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -u
```

## Refresh Domain Lists

When the domain list in this repository is updated, you can refresh without reinstalling:

```bash
bash dnsmasq_sniproxy.sh -r
```

This will re-download the latest domain list, regenerate both dnsmasq and sniproxy configs, and restart the services. It auto-detects which services are installed and only updates those.

You can also switch profiles during refresh:
```bash
bash dnsmasq_sniproxy.sh -r -p youtube
```

## After Installation

Set your device's DNS to the server's public IP. The script runs a health check automatically and displays the results.

To prevent abuse, avoid publishing the server IP publicly. Use firewall rules to restrict access.

### Custom Domains

To add custom domains after installation, edit:
- `/etc/dnsmasq.d/custom_netflix.conf` (DNS overrides)
- `/etc/sniproxy.conf` (SNI routing table)

Then restart both services:
```bash
systemctl restart dnsmasq
systemctl restart sniproxy
```

## Troubleshooting

**Check service status:**
```bash
systemctl status dnsmasq
systemctl status sniproxy
```

**Check logs:**
```bash
journalctl -u dnsmasq
journalctl -u sniproxy
```

**Check port listeners:**
```bash
ss -tlnp | grep -E ':(53|80|443) '
```

**Test DNS resolution:**
```bash
nslookup netflix.com <your-server-ip>
```
The resolved IP should match your server's public IP.

**Port conflicts:**
If sniproxy won't start, check if another service (e.g., nginx, apache) is using ports 80/443:
```bash
ss -tlnp | grep -E ':(80|443) '
```

**Cloud provider firewalls:**
Remember to also open ports 53, 80, 443 in your cloud provider's security group (AWS, GCP, Alibaba Cloud, etc.).

---

_This script is intended for unlocking streaming media only._
