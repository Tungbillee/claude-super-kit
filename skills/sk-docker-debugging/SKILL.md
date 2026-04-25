---
name: sk:docker-debugging
description: Docker and Docker Compose debugging techniques - logs, exec, container profiling, layer analysis with dive, build optimization (multi-stage, .dockerignore), networking troubleshooting.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: devops
argument-hint: "[Docker issue or optimization task]"
---

# sk:docker-debugging

Complete guide for debugging, profiling, and optimizing Docker containers and Compose stacks.

## When to Use

- Diagnosing why a container crashes or behaves unexpectedly
- Inspecting running containers interactively
- Analyzing Docker image layers to reduce image size
- Optimizing Dockerfile for faster builds and smaller images
- Debugging Docker Compose networking issues
- Profiling application performance inside containers

---

## 1. Container Logs

```bash
# Follow logs in real-time
docker logs -f <container_name>

# Last N lines
docker logs --tail=100 <container_name>

# With timestamps
docker logs -t <container_name>

# Since specific time
docker logs --since="2026-04-25T09:00:00" <container_name>
docker logs --since=2h <container_name>   # last 2 hours

# Docker Compose
docker compose logs -f api
docker compose logs -f --tail=50 api db
docker compose logs --no-log-prefix api  # clean output
```

---

## 2. Exec Into Running Container

```bash
# Interactive shell
docker exec -it <container_name> /bin/bash
docker exec -it <container_name> /bin/sh    # if bash not available

# Run single command
docker exec <container_name> env
docker exec <container_name> cat /etc/nginx/nginx.conf
docker exec <container_name> ls -la /app

# As specific user
docker exec -u root -it <container_name> /bin/bash
docker exec -u node -it <container_name> /bin/sh

# Set env vars
docker exec -e DEBUG=true -it <container_name> /bin/bash
```

### Debug a Stopped/Crashed Container

```bash
# Check exit code and last state
docker inspect <container_name> | jq '.[0].State'

# Copy files out of stopped container
docker cp <container_name>:/app/logs/error.log ./error.log

# Start with override entrypoint (bypasses CMD)
docker run -it --entrypoint /bin/sh my-image:latest

# Override CMD
docker run -it my-image:latest /bin/bash
```

---

## 3. Container Inspection

```bash
# Full container info
docker inspect <container_name>

# Network config
docker inspect <container_name> | jq '.[0].NetworkSettings'

# Mounted volumes
docker inspect <container_name> | jq '.[0].Mounts'

# Environment variables
docker inspect <container_name> | jq '.[0].Config.Env'

# Resource limits
docker inspect <container_name> | jq '.[0].HostConfig | {Memory, CpuShares, NanoCpus}'

# Running processes
docker top <container_name>

# Live resource usage
docker stats                        # all containers
docker stats <container_name>       # specific container
docker stats --no-stream            # snapshot (no follow)
```

---

## 4. Image Layer Analysis with dive

```bash
# Install dive
brew install dive              # macOS
# or
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  wagoodman/dive:latest my-image:latest

# Run dive
dive my-image:latest

# CI mode — fails if wasted space > threshold
dive my-image:latest --ci --lowestEfficiency=0.9
```

### dive Key Bindings
- `Tab` — switch between layers and filesystem views
- `Ctrl+A` — toggle added files
- `Ctrl+R` — toggle removed files
- `Ctrl+M` — toggle modified files
- `/` — filter files

---

## 5. Dockerfile Optimization

### Multi-Stage Build

```dockerfile
# Dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production=false
COPY . .
RUN npm run build

# Stage 2: Production (lean image)
FROM node:20-alpine AS production
WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./

USER appuser
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Layer Caching Strategy

```dockerfile
# BAD — invalidates cache on any source change
COPY . .
RUN npm ci

# GOOD — cache node_modules separately
COPY package*.json ./
RUN npm ci                  # cached unless package.json changes
COPY . .                    # source changes don't bust dep cache
RUN npm run build
```

### .dockerignore

```
node_modules
dist
.git
.gitignore
*.md
.env*
.DS_Store
coverage
.nyc_output
*.log
docker-compose*.yml
.github
tests
__tests__
*.test.*
*.spec.*
```

### Optimize Image Size

```dockerfile
# Use Alpine base
FROM node:20-alpine

# Combine RUN commands to reduce layers
RUN apk add --no-cache curl git \
    && npm install -g typescript \
    && rm -rf /var/cache/apk/*

# Remove dev dependencies after build
RUN npm ci && npm run build && npm prune --production

# Use specific version tags (not latest)
FROM node:20.11.1-alpine3.19
```

---

## 6. Docker Compose Debugging

```bash
# Validate compose file
docker compose config

# Start specific services
docker compose up -d api db

# Rebuild and restart
docker compose up -d --build api

# Scale service
docker compose up -d --scale worker=3

# Run one-off command
docker compose run --rm api npm run migrate

# Check service health
docker compose ps
docker compose events    # real-time events stream
```

### Override Compose for Development

```yaml
# docker-compose.override.yml (auto-loaded in dev)
services:
  api:
    build:
      target: development   # use dev stage
    volumes:
      - .:/app              # hot reload
      - /app/node_modules   # exclude from bind mount
    environment:
      - DEBUG=*
      - NODE_ENV=development
    command: npm run dev
```

---

## 7. Networking Troubleshooting

```bash
# List networks
docker network ls

# Inspect network (see connected containers + IPs)
docker network inspect my_network

# DNS resolution between containers
docker exec api_container nslookup db
docker exec api_container ping db

# Check port bindings
docker port <container_name>

# Test connectivity between containers
docker exec api_container curl http://db:5432
docker exec api_container nc -zv db 5432   # netcat

# Attach container to existing network
docker network connect my_network <container_name>
```

### Common Network Issues

```yaml
# docker-compose.yml — explicit network
services:
  api:
    networks: [backend]
  db:
    networks: [backend]
  nginx:
    networks: [frontend, backend]

networks:
  frontend:
  backend:
    internal: true    # no external access
```

---

## 8. Python Profiling Inside Container

```dockerfile
# Add profiling tools in dev stage
FROM python:3.12-slim AS development
RUN pip install cProfile pstats line_profiler memory_profiler
```

```bash
# Run with cProfile
docker exec -it api_container python -m cProfile -o /tmp/profile.out app.py

# Copy and analyze
docker cp api_container:/tmp/profile.out ./profile.out
python -c "
import pstats
p = pstats.Stats('profile.out')
p.sort_stats('cumulative')
p.print_stats(20)
"

# Memory profiling
docker exec -it api_container python -m memory_profiler app.py
```

---

## 9. Build Performance

```bash
# BuildKit (faster, better caching)
DOCKER_BUILDKIT=1 docker build .

# Or set in Docker config
# /etc/docker/daemon.json: { "features": { "buildkit": true } }

# Build with cache from registry
docker build --cache-from my-image:latest -t my-image:new .

# Multi-platform build
docker buildx build --platform linux/amd64,linux/arm64 -t my-image:latest .

# Inspect build cache
docker buildx du         # disk usage of build cache
docker buildx prune      # clean build cache
```

---

## Reference Docs

- [Docker Docs](https://docs.docker.com/)
- [dive GitHub](https://github.com/wagoodman/dive)
- [Docker Compose Docs](https://docs.docker.com/compose/)
- [BuildKit](https://docs.docker.com/build/buildkit/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Vấn đề bạn đang gặp là gì? (container crash / networking / image quá lớn / build chậm / performance)"
2. "Bạn dùng Docker standalone hay Docker Compose?"
3. "Language/runtime trong container: Node.js / Python / Go / Java?"

Cung cấp commands debug cụ thể và giải thích nguyên nhân thường gặp cho vấn đề của họ.
