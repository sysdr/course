# Docker Network Troubleshooting Guide

## Issue: Cannot reach Docker registry

### Quick Fixes:

#### 1. Restart Docker
```bash
# macOS
pkill Docker && open -a Docker

# Linux  
sudo systemctl restart docker
```

#### 2. Check DNS Resolution
```bash
nslookup registry-1.docker.io
# Should return IP addresses
```

#### 3. Corporate Network/Proxy
If behind corporate firewall, configure Docker proxy:

```bash
# Create or edit ~/.docker/config.json
{
  "proxies": {
    "default": {
      "httpProxy": "http://proxy.company.com:8080",
      "httpsProxy": "http://proxy.company.com:8080"
    }
  }
}
```

#### 4. Use Alternative Base Image
Update Dockerfile to use a different registry:

```dockerfile
# Instead of python:3.11-slim, try:
FROM python:3.11-alpine
# or
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y python3 python3-pip
```

#### 5. Build Without Cache
```bash
docker-compose build --no-cache --pull
```

#### 6. Check Docker Hub Status
Visit: https://status.docker.com/
