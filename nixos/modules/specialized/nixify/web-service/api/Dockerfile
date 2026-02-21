# Multi-stage build for Nixify Web Service
# Stage 1: Build Go binary
FROM golang:1.23-alpine AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
# Update go.sum to ensure correct hashes
RUN go mod tidy
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o nixify-web-service .

# Stage 2: Minimal runtime image
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata wget git

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/nixify-web-service .

# Create init script that clones repository on startup
# This ensures the container always has the latest NixOS structure from GitHub
RUN echo '#!/bin/sh' > /app/init.sh && \
    echo 'set -e' >> /app/init.sh && \
    echo '' >> /app/init.sh && \
    echo '# Get GitHub repo URL from environment or use default' >> /app/init.sh && \
    echo 'GITHUB_REPO="${GITHUB_REPO_URL:-https://github.com/fr4iser90/NixOSControlCenter.git}"' >> /app/init.sh && \
    echo 'GITHUB_BRANCH="${GITHUB_BRANCH:-main}"' >> /app/init.sh && \
    echo '' >> /app/init.sh && \
    echo '# Clone repository if nixos structure does not exist' >> /app/init.sh && \
    echo 'if [ ! -d "/app/nixos" ] || [ ! -f "/app/nixos/flake.nix" ]; then' >> /app/init.sh && \
    echo '  echo "📦 Cloning NixOS Control Center from GitHub..."' >> /app/init.sh && \
    echo '  echo "   Repository: ${GITHUB_REPO}"' >> /app/init.sh && \
    echo '  echo "   Branch: ${GITHUB_BRANCH}"' >> /app/init.sh && \
    echo '  ' >> /app/init.sh && \
    echo '  # Clone repository to temporary location' >> /app/init.sh && \
    echo '  TMP_DIR=$(mktemp -d)' >> /app/init.sh && \
    echo '  git clone --depth 1 --branch "${GITHUB_BRANCH}" "${GITHUB_REPO}" "${TMP_DIR}" || {' >> /app/init.sh && \
    echo '    echo "❌ Failed to clone repository"' >> /app/init.sh && \
    echo '    exit 1' >> /app/init.sh && \
    echo '  }' >> /app/init.sh && \
    echo '  ' >> /app/init.sh && \
    echo '  # Move nixos structure to /app/nixos' >> /app/init.sh && \
    echo '  if [ -d "${TMP_DIR}/nixos" ]; then' >> /app/init.sh && \
    echo '    mv "${TMP_DIR}/nixos" /app/nixos' >> /app/init.sh && \
    echo '    echo "✅ NixOS structure loaded successfully"' >> /app/init.sh && \
    echo '  else' >> /app/init.sh && \
    echo '    echo "❌ nixos/ directory not found in repository"' >> /app/init.sh && \
    echo '    rm -rf "${TMP_DIR}"' >> /app/init.sh && \
    echo '    exit 1' >> /app/init.sh && \
    echo '  fi' >> /app/init.sh && \
    echo '  ' >> /app/init.sh && \
    echo '  # Cleanup temporary directory' >> /app/init.sh && \
    echo '  rm -rf "${TMP_DIR}"' >> /app/init.sh && \
    echo 'else' >> /app/init.sh && \
    echo '  echo "✅ NixOS structure already exists, skipping clone"' >> /app/init.sh && \
    echo 'fi' >> /app/init.sh && \
    echo '' >> /app/init.sh && \
    echo '# Start the web service' >> /app/init.sh && \
    echo 'exec /app/nixify-web-service' >> /app/init.sh && \
    chmod +x /app/init.sh

# Create non-root user for security
RUN addgroup -g 1000 nixify && \
    adduser -D -u 1000 -G nixify nixify

# Create data directory with proper permissions
RUN mkdir -p /var/lib/nixify && \
    chown -R nixify:nixify /var/lib/nixify && \
    chown -R nixify:nixify /app

# Expose port
EXPOSE 8080

# Environment variables
ENV PORT=8080
ENV HOST=0.0.0.0
ENV DATA_DIR=/var/lib/nixify
ENV GITHUB_REPO_URL=https://github.com/fr4iser90/NixOSControlCenter.git
ENV GITHUB_BRANCH=main

# Switch to non-root user
USER nixify

# Run init script which clones repo and starts service
CMD ["/app/init.sh"]
