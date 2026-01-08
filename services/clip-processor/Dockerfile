# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -o clip-processor main.go

# Runtime stage
FROM alpine:latest

# Install ffmpeg and ffprobe
RUN apk add --no-cache ffmpeg ca-certificates

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/clip-processor .

# Expose port
EXPOSE 8080

# Run the service
CMD ["./clip-processor"]
