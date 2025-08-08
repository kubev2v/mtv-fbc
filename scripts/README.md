# Scripts Directory

This directory contains utility and testing scripts for the MTV (Migration Toolkit for Virtualization) File-Based Catalog (FBC) project.

## Quick Troubleshooting

**If tests are failing:**

1. **Check container runtime:**
   - Docker: `docker info` (if not working, start Docker Desktop or `sudo systemctl start docker`)
   - Podman: `podman --version` (usually works without daemon)
   - Script will auto-detect and use available option
2. **Check you're in the right directory:** The script should be run from project root
3. **Red Hat registry access:** Base images may require authentication
4. **Network connectivity:** Ensure you can reach external registries

## Available Scripts

### `test-event-title.sh`

A comprehensive testing script for validating the EVENT_TITLE functionality in the Docker builds and Tekton pipelines.

#### What it tests

This script validates that:
- Docker builds successfully accept the `EVENT_TITLE` build argument
- The `mtv-version` label is correctly set with the "v" prefix
- Different types of EVENT_TITLE values work correctly (semver versions, commit messages, PR titles)

#### Prerequisites

- **Container runtime** - Either Docker or Podman:
  - **Docker:** Requires daemon to be running
    - On macOS: Start Docker Desktop application
    - On Linux: `sudo systemctl start docker`
    - Verify with: `docker info`
  - **Podman:** Works without daemon (recommended alternative)
    - Usually works immediately after installation
    - On macOS: May need `podman machine start`
    - Verify with: `podman --version`
- Access to the base images specified in the Dockerfiles (Red Hat registry)
- Sufficient disk space for temporary container images

#### Usage

```bash
# From the project root directory
./scripts/test-event-title.sh
```

#### What the script does

1. **Tests multiple scenarios** with different EVENT_TITLE values:
   - Semantic version: `1.2.3`
   - Pre-release version: `2.0.0-rc.1`
   - Commit message: `Fix critical security issue`
   - Feature commit: `feat: Add new authentication method`
   - Version tag: `v3.1.0`

2. **For each test case**:
   - Builds a Docker image using `v4.20/catalog.Dockerfile`
   - Passes the test value as `EVENT_TITLE` build argument
   - Inspects the resulting image for the `mtv-version` label
   - Verifies the label has the correct "v" prefix
   - Cleans up the temporary image

#### Expected Output

```
Testing EVENT_TITLE functionality...

Testing with EVENT_TITLE: '1.2.3'
Building image with tag: test-mtv-1-2-3
✅ Build successful
✅ Label found: mtv-version=v1.2.3

Testing with EVENT_TITLE: '2.0.0-rc.1'
Building image with tag: test-mtv-2-0-0-rc-1
✅ Build successful
✅ Label found: mtv-version=v2.0.0-rc.1

...
```

#### Troubleshooting

**Build failures:**
- Ensure Docker is running
- Check that base images are accessible (Red Hat registry access may be required)
- Verify you have sufficient disk space
- Note: Build failures due to missing base images are expected in some environments

**Missing labels:**
- Check that the Dockerfile has both `ARG EVENT_TITLE` and `LABEL mtv-version=v${EVENT_TITLE}`
- Ensure the Docker build completed successfully

**Permission errors:**
- Make sure the script is executable: `chmod +x scripts/test-event-title.sh`

**Red Hat Registry Access:**
- The base images are from `registry.redhat.io` which may require authentication
- You can test the Dockerfile syntax without building by running: `docker build --dry-run -f v4.20/catalog.Dockerfile .`

## Manual Testing

### Testing Individual Dockerfiles

You can test individual Dockerfiles manually:

```bash
# Test with a specific version
docker build -f v4.20/catalog.Dockerfile --build-arg EVENT_TITLE="1.2.3" -t test-mtv:latest .

# Inspect the result
docker inspect test-mtv:latest | grep -A2 -B2 "mtv-version"

# Clean up
docker rmi test-mtv:latest
```

### Testing Different Versions

Test all supported OpenShift versions:

```bash
# Test each version directory
for version in v4.14 v4.15 v4.16 v4.17 v4.18 v4.19 v4.20; do
  echo "Testing $version..."
  docker build -f $version/catalog.Dockerfile --build-arg EVENT_TITLE="test-version" -t test-$version .
  docker inspect test-$version | grep mtv-version
  docker rmi test-$version
done
```

## Pipeline Integration Testing

### Pull Request Testing

1. Create a pull request with a title containing a version:
   ```
   v1.2.3 - Add new operator support
   ```

2. Check the pipeline logs to ensure `EVENT_TITLE={{body.pull_request.title}}` is passed correctly

3. Inspect the resulting image:
   ```bash
   # Get the image from the pipeline output
   docker pull <pipeline-output-image>
   docker inspect <pipeline-output-image> | grep mtv-version
   ```

### Push Event Testing

1. Make a commit with a version in the message:
   ```bash
   git commit -m "Release v1.2.3"
   git push origin main
   ```

2. Check the pipeline logs to ensure `EVENT_TITLE={{body.head_commit.message}}` is passed correctly

3. Inspect the resulting image for the `mtv-version` label

## Configuration Verification

### Check Pipeline Configuration

Verify all Tekton pipeline files have the EVENT_TITLE configuration:

```bash
# From project root
grep -r "EVENT_TITLE" .tekton/
```

Expected output should show EVENT_TITLE in both pull-request and push pipeline files for all versions.

### Check Dockerfile Configuration

Verify all Dockerfiles have the ARG and LABEL:

```bash
# From project root
grep -r "EVENT_TITLE" */catalog.Dockerfile
```

Expected output should show both `ARG EVENT_TITLE` and `LABEL mtv-version=v${EVENT_TITLE}` for all version directories.

## Contributing

When adding new scripts to this directory:

1. Make scripts executable: `chmod +x script-name.sh`
2. Add documentation to this README
3. Include error handling and cleanup in scripts
4. Test scripts thoroughly before committing

## Files in this directory

- `test-event-title.sh` - Tests EVENT_TITLE functionality across all components
- `README.md` - This documentation file

## Related Documentation

- [Tekton Pipeline Documentation](../.tekton/)
- [Docker Build Arguments Documentation](https://docs.docker.com/engine/reference/builder/#arg)
- [Container Image Labels](https://docs.docker.com/engine/reference/builder/#label)
