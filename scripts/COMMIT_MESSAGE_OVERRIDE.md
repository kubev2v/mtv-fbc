# Commit Message Override for MTV-Version Labels

This document explains how the MTV-FBC pipelines now support commit message overrides for version labels in pull request contexts.

## Overview

The MTV-FBC build system now provides **conditional version labeling** for pull requests:

- **Default**: Uses the PR title for the `mtv-version` label
- **Override**: Uses the commit message if it contains `MTV-Version:`

This allows developers to update version labels by pushing new commits to an existing PR without having to modify the PR title.

## How It Works

### Current Implementation (Basic)

The PR pipelines use conditional template logic that checks for override patterns:

```yaml
- name: label-templates
  value:
  - "mtv-version=v{{if contains (body.head_commit.message) \"MTV-Version\"}}{{body.head_commit.message}}{{else}}{{body.pull_request.title}}{{end}}"
```

**Current Decision Logic:**
1. **Check commit message**: Does it contain the string `MTV-Version`?
2. **If YES**: Use the entire commit message as the version label
3. **If NO**: Fall back to the PR title (original behavior)

### Enhanced Implementation (Available via Custom Task)

For semantic version extraction, a custom Tekton task can provide:

**Enhanced Decision Logic:**
1. **MTV-Version Override**: Extract semver from `MTV-Version: x.x.x` pattern
2. **Commit Semver Detection**: Auto-detect semver patterns in commit messages
3. **PR Title Semver Detection**: Auto-detect semver patterns in PR titles  
4. **Fallback**: Use PR title if no semver patterns found

**Enhanced Extraction Examples:**
- `MTV-Version: 1.5.0` → `v1.5.0` (extracts semver only)
- `Release v2.0.0 candidate` → `v2.0.0` (auto-detects semver)
- `v1.2.3 - Bug fixes` → `v1.2.3` (extracts from PR title)

## Usage Examples

### Scenario 1: Standard PR (No Override)

**PR Title**: `v1.2.3 - Security fixes`  
**Commit Message**: `Fix critical vulnerability in auth module`  
**Result**: `mtv-version=vv1.2.3 - Security fixes`

*Uses PR title because commit message doesn't contain `MTV-Version`*

### Scenario 2: Commit Message Override

**PR Title**: `Update documentation`  
**Commit Message**: 
```
Fix critical security vulnerability

MTV-Version: 1.5.0
```
**Result**: `mtv-version=vFix critical security vulnerability\n\nMTV-Version: 1.5.0`

*Uses entire commit message because it contains `MTV-Version`*

### Scenario 3: Updating Version in Existing PR

**Initial Commit**: `Add new feature` (uses PR title)  
**New Commit**: 
```
Update feature with security improvements

MTV-Version: 2.0.0-beta
```
**Result**: `mtv-version=vUpdate feature with security improvements\n\nMTV-Version: 2.0.0-beta`

*Latest commit overrides the version*

## Best Practices

### For Clean Version Labels

If you want clean version labels when using commit message override, structure your commit messages appropriately:

#### Option 1: Version-only commit message
```bash
git commit -m "MTV-Version: 1.5.0"
```
**Result**: `mtv-version=vMTV-Version: 1.5.0`

#### Option 2: Use PR title for versions
Keep using PR titles for clean version labels:
**PR Title**: `1.5.0`
**Result**: `mtv-version=v1.5.0`

### When to Use Override

Use commit message override when:
- You need to update the version after creating the PR
- You want the version to be tied to specific commits
- You're making multiple version changes in one PR

Use PR title when:
- You want a clean, simple version label
- The version is determined when creating the PR
- You prefer the original behavior

## Technical Implementation

### Updated Files

All PR pipeline files have been updated:
- `forklift-fbc-comp-prod-v416-pull-request.yaml`
- `forklift-fbc-comp-prod-v417-pull-request.yaml`
- `forklift-fbc-comp-prod-v418-pull-request.yaml`
- `forklift-fbc-comp-prod-v419-pull-request.yaml`
- `forklift-fbc-comp-prod-v420-pull-request.yaml`

### Template Syntax

The conditional template uses Go template syntax:
- `contains (body.head_commit.message) "MTV-Version"` - Checks for override pattern
- `{{if}}...{{else}}...{{end}}` - Conditional logic
- `body.head_commit.message` - Latest commit message
- `body.pull_request.title` - PR title

### Limitations

1. **Entire Message**: When override is detected, the entire commit message becomes the version label
2. **No Extraction**: The current implementation doesn't extract just the version number
3. **Case Sensitive**: The pattern `MTV-Version` is case-sensitive

## Testing

### Current Implementation Testing

Use the test script to validate both current and enhanced conditional logic:

```bash
./scripts/test-commit-override.sh
```

This script provides:
- **Current behavior simulation**: How the basic conditional template works
- **Enhanced behavior demonstration**: How semver extraction would work
- **Pipeline verification**: Confirms all PR pipelines are updated
- **Multiple test scenarios**: Various commit message and PR title patterns

### Test Coverage

The test script validates:
1. **MTV-Version Override**: `MTV-Version: 1.5.0` → `v1.5.0`
2. **Automatic Semver Detection**: `Release v2.0.0` → `v2.0.0`
3. **PR Title Fallback**: Uses PR title when no commit semver found
4. **Case Sensitivity**: Ensures `MTV-Version` is case-sensitive
5. **Complex Scenarios**: Multi-line commit messages with overrides

## Implementation Options

### Option 1: Current Implementation (Active)
- ✅ **Deployed**: Working in all PR pipelines
- ✅ **Simple**: Uses basic Go template conditional logic
- ⚠️ **Limitation**: Uses entire commit message when override detected

### Option 2: Enhanced Implementation (Available)
- 📋 **Ready**: Custom Tekton task available in `../tekton-tasks/extract-semver-task.yaml`
- ✅ **Smart**: Extracts only semver from patterns
- ✅ **Flexible**: Auto-detects semver in commits and PR titles
- 🔧 **Requires**: Deployment of custom task to cluster

### Migration Path

To upgrade to enhanced semver extraction:

1. **Deploy Custom Task**:
   ```bash
   kubectl apply -f tekton-tasks/extract-semver-task.yaml
   ```

2. **Update Pipeline Templates**:
   ```yaml
   # Add before generate-labels task
   - name: extract-semver
     params:
     - name: commit-message
       value: "{{body.head_commit.message}}"
     - name: pr-title
       value: "{{body.pull_request.title}}"
   
   # Update generate-labels task  
   - name: generate-labels
     params:
     - name: label-templates
       value:
       - "mtv-version={{tasks.extract-semver.results.version}}"
     runAfter:
     - extract-semver
   ```

3. **Test**: Use the test script to validate behavior before deployment

## Migration Impact

### Backward Compatibility

- **Existing PRs**: Will continue to work as before (using PR title)
- **No Override**: Default behavior unchanged
- **Existing Workflows**: No changes needed

### New Behavior

- **New PRs**: Can now use commit message override
- **Existing PRs**: Can be updated with new commits containing override

## Troubleshooting

### Override Not Working?

1. **Check Pattern**: Ensure commit message contains exactly `MTV-Version:` (case-sensitive)
2. **Check Pipeline Logs**: Look for the `generate-labels` task output
3. **Verify Template**: Confirm the pipeline files have the new conditional template

### Unexpected Version Label?

1. **Entire Message**: Remember that the entire commit message becomes the label when override is detected
2. **Latest Commit**: Only the most recent commit message is checked
3. **Pattern Match**: Must contain `MTV-Version:` string exactly

## Examples in Practice

### Workflow Example

1. **Create PR** with title `Update authentication system`
   - Gets `mtv-version=vUpdate authentication system`

2. **Push commit** with message `Fix bug in auth module`
   - Still gets `mtv-version=vUpdate authentication system` (no override)

3. **Push commit** with message:
   ```
   Complete authentication rewrite
   
   MTV-Version: 2.0.0
   ```
   - Now gets `mtv-version=vComplete authentication rewrite\n\nMTV-Version: 2.0.0`

This provides flexibility to update versions via commits while maintaining backward compatibility with PR title-based versioning.
