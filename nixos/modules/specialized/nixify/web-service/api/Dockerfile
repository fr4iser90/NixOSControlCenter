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

# Create data directory
RUN mkdir -p /var/lib/nixify

# Expose port
EXPOSE 8080

# Environment variables
ENV PORT=8080
ENV HOST=0.0.0.0
ENV DATA_DIR=/var/lib/nixify

# Run the service
CMD ["./nixify-web-service"]
