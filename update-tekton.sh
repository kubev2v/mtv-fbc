#!/bin/bash

# Use this script to update the Tekton Task Bundle references used in a Pipeline or a PipelineRun.
# Valid versions and digests are taken from the data-acceptable-bundles image, which is
# generated from konflux-ci/build-definitions and is what Konflux validates pipelines against.
# Usage: update-tekton.sh .tekton/*.yaml

set +e -uo pipefail

FILES=$@

# Fetch the list of acceptable task bundles
ACCEPTABLE_DIR=$(mktemp -d)
trap 'rm -rf "$ACCEPTABLE_DIR"' EXIT
if ! skopeo copy docker://quay.io/konflux-ci/tekton-catalog/data-acceptable-bundles:latest dir:"$ACCEPTABLE_DIR" >/dev/null 2>&1; then
  echo "Failed to fetch data-acceptable-bundles" >&2
  exit 1
fi
ACCEPTABLE_DATA=$(grep -l "trusted_tasks:" "$ACCEPTABLE_DIR"/*)
if [[ -z "$ACCEPTABLE_DATA" ]]; then
  echo "Could not find trusted_tasks data in data-acceptable-bundles" >&2
  exit 1
fi

# Find existing image references
OLD_REFS="$(
  yq '... | select(has("resolver")) | .params // [] | .[] | select(.name == "bundle") | .value' $FILES |
    grep -v -- '---' |
    sort -u
)"

# Find updates for image references
for old_ref in ${OLD_REFS}; do
  repo_tag="${old_ref%@*}"
  echo "Processing: $repo_tag"
  task_ver=${repo_tag#*:}
  task_name=${repo_tag%:*}
  latest_tag=$(grep -oE "oci://${task_name}:[0-9]+(\.[0-9]+)*:" "$ACCEPTABLE_DATA" |
    awk -F: '{print $3}' | sort -V -u | tail -1)
  if [[ -z "$latest_tag" ]]; then
    echo "No acceptable bundle found for ${task_name}, skipping" >&2
    continue
  fi
  new_digest=$(yq ".trusted_tasks[\"oci://${task_name}:${latest_tag}\"][0].ref" "$ACCEPTABLE_DATA")
  new_ref="${task_name}:${latest_tag}@${new_digest}"
  [[ $new_ref == $old_ref ]] && continue
  if [[ "$latest_tag" != "$task_ver" ]]; then
    echo "New version found! $new_ref"
  else
    echo "New digest found! $new_ref"
  fi
  for file in $FILES; do
    sed -i.bak "s!${old_ref}!${new_ref}!g" "$file" && rm -f "${file}.bak"
  done
done
