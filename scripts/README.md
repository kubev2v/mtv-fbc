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

### `test-commit-override.sh`

A comprehensive test script for **commit message override functionality** in pull request pipelines.

This script validates:
- Conditional template logic that checks for `MTV-Version:` in commit messages
- Fallback behavior to PR title when no override is found
- Case sensitivity of the override pattern
- Pipeline file verification to ensure all PR pipelines are updated

#### Usage

```bash
# From the project root directory
./scripts/test-commit-override.sh
```

#### What this tests

1. **Override Detection**: Tests various commit message patterns with and without `MTV-Version:`
2. **Fallback Logic**: Validates that PR title is used when no override is detected
3. **Template Syntax**: Explains the Go template conditional logic used in pipelines
4. **Pipeline Verification**: Checks that all PR pipeline files have been updated
5. **Usage Examples**: Demonstrates real-world workflow scenarios

### `test-generate-labels-local.sh`

A comprehensive local testing script that **simulates the complete generate-labels workflow** end-to-end, including label generation and application.

This script provides:
- Full local simulation of the generate-labels + buildah LABELS workflow
- Template substitution testing (simulates what Tekton does)
- Label generation from different event types (pull requests, pushes)
- Actual label application and verification on container images
- Comparison between old and new approaches

#### Usage

```bash
# From the project root directory
./scripts/test-generate-labels-local.sh
```

#### What this tests

1. **Generate-Labels Simulation**: Simulates the generate-labels task creating labels from templates
2. **Label Application**: Creates images with labels applied externally (simulating buildah LABELS parameter)
3. **Template Substitution**: Tests Tekton template substitution ({{body.pull_request.title}}, etc.)
4. **End-to-End Verification**: Validates the complete workflow produces correct labels
5. **Multiple Event Types**: Tests both pull request and push event scenarios

#### Expected Output

```
Testing generate-labels approach locally...
✅ Using Podman (Docker not available)

🔍 Local Generate-Labels Testing...

Testing pull_request event with value: '1.2.3'
Generated label: mtv-version=v1.2.3
Building base image...
✅ Base build successful
Applying labels locally (simulating buildah LABELS parameter)...
✅ Labels applied successfully
✅ Label verified: mtv-version=v1.2.3

...
```

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

## Manual Testing

### Testing Individual Dockerfiles

You can test individual Dockerfiles manually:

```bash
# Test basic build (no labels, labels applied externally in production)
docker build -f v4.20/catalog.Dockerfile -t test-mtv:latest .

# Inspect the result (should not contain mtv-version labels)
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
  docker build -f $version/catalog.Dockerfile -t test-$version .
  docker rmi test-$version
done
```

## Pipeline Integration Testing

### Pull Request Testing

1. Create a pull request with a title containing a version:
   ```
   v1.2.3 - Add new operator support
   ```

2. Check the pipeline logs to ensure `generate-labels` task creates the correct label template

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

2. Check the pipeline logs to ensure `generate-labels` task processes the commit message correctly

3. Inspect the resulting image for the `mtv-version` label

## Configuration Verification

### Check Pipeline Configuration

Verify all Tekton pipeline files have the generate-labels configuration:

```bash
# From project root
grep -r "generate-labels" .tekton/
```

Expected output should show generate-labels tasks in both pull-request and push pipeline files for all versions.

### Check Dockerfile Configuration

Verify all Dockerfiles are clean (no ARG/LABEL for mtv-version):

```bash
# From project root
grep -r "mtv-version\|EVENT_TITLE" */catalog.Dockerfile
```

Expected output should be empty - labels are now applied externally by the build system.

## Contributing

When adding new scripts to this directory:

1. Make scripts executable: `chmod +x script-name.sh`
2. Add documentation to this README
3. Include error handling and cleanup in scripts
4. Test scripts thoroughly before committing

## Files in this directory

- `test-commit-override.sh` - Tests commit message override functionality for PR pipelines
- `test-generate-labels-local.sh` - Tests generate-labels functionality with full local simulation
- `COMMIT_MESSAGE_OVERRIDE.md` - Complete guide for commit message override feature
- `README.md` - This documentation file

## Related Documentation

- [Commit Message Override Guide](COMMIT_MESSAGE_OVERRIDE.md) - **How to use commit message overrides in PR pipelines**
- [Tekton Pipeline Documentation](../.tekton/)
- [Konflux Generate-Labels Documentation](https://konflux-ci.dev/docs/building/labels-and-annotations/#generating-dynamic-labels-or-annotations)
- [Container Image Labels](https://docs.docker.com/engine/reference/builder/#label)