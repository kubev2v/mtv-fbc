#!/bin/bash

echo "Testing EVENT_TITLE functionality..."

# Determine which container tool to use
CONTAINER_CMD=""

# Try Docker first
if docker info >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
    echo "✅ Using Docker"
# Fall back to Podman
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
    echo "✅ Using Podman (Docker not available)"
else
    echo ""
    echo "❌ Neither Docker nor Podman is available!"
    echo ""
    echo "Please install and configure one of the following:"
    echo "- Docker: https://docs.docker.com/get-docker/"
    echo "- Podman: https://podman.io/getting-started/installation"
    echo ""
    echo "For Docker:"
    echo "- On macOS: Open Docker Desktop application"
    echo "- On Linux: sudo systemctl start docker"
    echo ""
    echo "For Podman:"
    echo "- Usually works without a daemon"
    echo "- On macOS: podman machine start (if using podman machine)"
    echo ""
    exit 1
fi

# Check if the Dockerfile exists
dockerfile="v4.20/catalog.Dockerfile"
if [ ! -f "$dockerfile" ]; then
    echo "❌ Dockerfile not found: $dockerfile"
    echo "Make sure you're running this script from the project root directory"
    exit 1
fi

echo "✅ Dockerfile found: $dockerfile"
echo ""

# Test different scenarios
test_cases=(
    "1.2.3"
    "2.0.0-rc.1"
    "Fix critical security issue"
    "feat: Add new authentication method"
    "v3.1.0"
)

# Test with v4.20 Dockerfile
dockerfile="v4.20/catalog.Dockerfile"

for test_case in "${test_cases[@]}"; do
    echo ""
    echo "Testing with EVENT_TITLE: '$test_case'"
    
    # Build the image
    tag="test-mtv-$(echo "$test_case" | tr ' .:' '-' | tr '[:upper:]' '[:lower:]')"
    echo "Building image with tag: $tag"
    
    # Attempt the build and capture output
    build_output=$($CONTAINER_CMD build -f "$dockerfile" --build-arg EVENT_TITLE="$test_case" -t "$tag" . 2>&1)
    build_result=$?
    
    if [ $build_result -eq 0 ]; then
        echo "✅ Build successful"
        
        # Extract the mtv-version label
        mtv_version=$($CONTAINER_CMD inspect "$tag" --format='{{index .Config.Labels "mtv-version"}}' 2>/dev/null)
        
        if [ -n "$mtv_version" ]; then
            echo "✅ Label found: mtv-version=$mtv_version"
        else
            echo "❌ Label not found"
        fi
        
        # Clean up
        $CONTAINER_CMD rmi "$tag" --force >/dev/null 2>&1
    else
        echo "❌ Build failed"
        
        # Show specific error information
        if echo "$build_output" | grep -q "pull access denied\|unauthorized"; then
            echo "   → Registry access issue (Red Hat registry may require authentication)"
        elif echo "$build_output" | grep -q "no such file or directory"; then
            echo "   → File not found (check catalog directory exists)"
        elif echo "$build_output" | grep -q "network\|timeout"; then
            echo "   → Network connectivity issue"
        else
            echo "   → See full error with: $CONTAINER_CMD build -f $dockerfile --build-arg EVENT_TITLE=\"$test_case\" -t $tag ."
        fi
    fi
done

echo ""
echo "Testing complete!"
echo ""
echo "To test the full pipeline:"
echo "1. Create a PR with title like 'v1.2.3 - New release'"
echo "2. Make a commit with message like 'Release v1.2.3'"
echo "3. Check the pipeline logs and resulting image labels"
