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

RUN apk --no-cache add ca-certificates tzdata wget

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/nixify-web-service .

# Copy complete NixOS structure from repository root
# This allows the Go service to read module files directly and understand the full structure
COPY nixos/core /app/nixos/core
COPY nixos/modules /app/nixos/modules
COPY nixos/custom /app/nixos/custom
COPY nixos/configs /app/nixos/configs
COPY nixos/flake.nix /app/nixos/flake.nix
COPY nixos/flake.lock /app/nixos/flake.lock

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

# Switch to non-root user
USER nixify

# Run the service
CMD ["./nixify-web-service"]
