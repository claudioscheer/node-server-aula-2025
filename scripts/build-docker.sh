#!/bin/bash

# Docker build script for SoloHub Server
# Usage: ./scripts/build-docker.sh [options]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="solohub-server"
TAG="latest"
ENVIRONMENT="production"
BUILD_ARGS=""
NO_CACHE=false
PUSH=false
REGISTRY=""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME        Docker image name (default: solohub-server)"
    echo "  -t, --tag TAG          Docker image tag (default: latest)"
    echo "  -e, --env ENV          Environment: dev, test, prod (default: production)"
    echo "  -r, --registry REG     Docker registry URL"
    echo "  -p, --push             Push image to registry after build"
    echo "  --no-cache             Build without using cache"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build with defaults"
    echo "  $0 -t v1.0.0 -e prod                 # Build production image with tag v1.0.0"
    echo "  $0 -e dev --no-cache                 # Build dev image without cache"
    echo "  $0 -r myregistry.com -p              # Build and push to registry"
}

# Function to log messages
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -p|--push)
            PUSH=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate environment
case $ENVIRONMENT in
    dev|development)
        ENVIRONMENT="development"
        BUILD_ARGS="--build-arg NODE_ENV=development"
        ;;
    test|testing)
        ENVIRONMENT="test"
        BUILD_ARGS="--build-arg NODE_ENV=test"
        ;;
    prod|production)
        ENVIRONMENT="production"
        BUILD_ARGS="--build-arg NODE_ENV=production"
        ;;
    *)
        log_error "Invalid environment: $ENVIRONMENT. Use dev, test, or prod"
        exit 1
        ;;
esac

# Construct full image name
if [[ -n "$REGISTRY" ]]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${TAG}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"
fi

# Display build information
log "Starting Docker build..."
log "Image name: $FULL_IMAGE_NAME"
log "Environment: $ENVIRONMENT"
log "No cache: $NO_CACHE"
log "Push after build: $PUSH"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if .env file exists for production builds
if [[ "$ENVIRONMENT" == "production" && ! -f ".env" ]]; then
    log_warning ".env file not found. Make sure environment variables are properly configured."
fi

# Build the Docker image
log "Building Docker image..."

BUILD_CMD="docker build"
if [[ "$NO_CACHE" == true ]]; then
    BUILD_CMD="$BUILD_CMD --no-cache"
fi

if [[ -n "$BUILD_ARGS" ]]; then
    BUILD_CMD="$BUILD_CMD $BUILD_ARGS"
fi

BUILD_CMD="$BUILD_CMD -t $FULL_IMAGE_NAME ."

log "Executing: $BUILD_CMD"

if eval $BUILD_CMD; then
    log_success "Docker image built successfully: $FULL_IMAGE_NAME"
else
    log_error "Docker build failed"
    exit 1
fi

# Show image information
log "Image information:"
docker images "$FULL_IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Push to registry if requested
if [[ "$PUSH" == true ]]; then
    if [[ -z "$REGISTRY" ]]; then
        log_error "Registry not specified. Use -r or --registry option to specify registry URL."
        exit 1
    fi
    
    log "Pushing image to registry..."
    if docker push "$FULL_IMAGE_NAME"; then
        log_success "Image pushed successfully: $FULL_IMAGE_NAME"
    else
        log_error "Failed to push image to registry"
        exit 1
    fi
fi

# Show next steps
log_success "Build completed successfully!"
echo ""
echo "Next steps:"
echo "  Run the container:"
echo "    docker run -p 3000:3000 --env-file .env $FULL_IMAGE_NAME"
echo ""
echo "  Or use docker-compose:"
echo "    docker-compose up"
echo ""
if [[ "$PUSH" == false && -n "$REGISTRY" ]]; then
    echo "  To push to registry:"
    echo "    docker push $FULL_IMAGE_NAME"
fi
