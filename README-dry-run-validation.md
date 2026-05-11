# Validating the dry-run bundle in FBC

The **dry-run** operator bundle (built by the forklift repo’s dry-run pipeline) is a normal OLM bundle image. You can validate it in FBC using the same process as for production bundles.

## Do you need to do anything different?

**No.** Template format and render steps are the same. Only the **image ref** and **where** you add it change.

### 1. Template format (unchanged)

Add an `olm.bundle` entry with the dry-run image (digest recommended):

```json
{"schema":"olm.bundle","image":"quay.io/redhat-user-workloads/rh-mtv-1-tenant/forklift-operator-2-10/forklift-operator-bundle-dry-run-2-10@sha256:<digest>"}
```

Add an `olm.channel` entry that references the bundle name that will be rendered (e.g. `mtv-operator.v2.12.0` from the dry-run bundle’s CSV). Render with an optional template path:

```bash
# Production template (default)
./generate-fbc.sh --render-template v4.20

# Dry-run template
./generate-fbc.sh --render-template v4.20 --template catalog-template-dry-run.json
```

`opm alpha render-template` will pull the dry-run bundle image and fill in name, package, and properties like any other bundle.

### 2. Where to add the dry-run bundle

- **Production FBC (e.g. `v4.20/catalog-template.json`):** Do **not** add the dry-run image. Production should reference only released bundle images (`registry.redhat.io/...`).
- **Validating dry-run in FBC:** Use one of:
  - A **separate template** (e.g. `v4.20/catalog-template-dry-run.json`): copy the production template, add the dry-run bundle image and a channel entry, render to a separate catalog dir (or a temp dir), then run the FBC build/validate pipeline against that. Production catalog stays unchanged.
  - A **staging-only** OCP version or branch: add the dry-run bundle to the template there and re-render so the staging FBC includes it for testing.

**Dry-run templates on this branch:** `v4.20/catalog-template-dry-run.json`, `v4.21/catalog-template-dry-run.json`, and `v4.22/catalog-template-dry-run.json` are provided for stage-branch validation. Each contains a single channel `dry-run` and one bundle pointing at the dry-run image (`:latest`; replace with `@sha256:<digest>` after you have a build). The channel entry uses bundle name `mtv-operator.v2.10.0`—if your dry-run CSV version differs, run `opm alpha render-template` on the dry-run image to get the exact bundle name and update the channel entry.

**Rendering a dry-run template:** Run e.g. `./generate-fbc.sh --render-template v4.20 --template catalog-template-dry-run.json` (or use `v4.21` / `v4.22` for those OCP versions). This writes the rendered catalog to `<frag>/catalog/mtv-operator/catalog.json`. Commit that path before triggering the dry-run FBC build (see below).

### 3. Getting the dry-run image ref

Use the image produced by the dry-run pipeline (by tag or digest):

- Tag: `quay.io/redhat-user-workloads/rh-mtv-1-tenant/forklift-operator-2-10/forklift-operator-bundle-dry-run-2-10:<revision>`
- Digest: from pipeline result `IMAGE_DIGEST` or by inspecting the tag.

Prefer `@sha256:<digest>` in the template for reproducibility.

## Summary

| Step              | Production bundle     | Dry-run bundle                          |
|-------------------|------------------------|-----------------------------------------|
| Template entry    | `olm.bundle` + image   | Same; image = dry-run image ref         |
| Channel entry     | Yes                    | Yes (channel that references new bundle)|
| Render            | `--render-template`    | Same                                    |
| Where to add      | Production template    | Separate template or staging catalog    |

No changes are required to the FBC implementation; only the image ref and which template/catalog you edit.

---

## Building the dry-run FBC image (Tekton)

Tekton pipelines are provided to build the dry-run FBC image for **v4.20, v4.21, and v4.22**. The catalog is **not** rendered in the pipeline; you must render it locally and commit the fragment’s `catalog` (e.g. `v4.20/catalog`) before the build runs.

### Script: template path support

`generate-fbc.sh` supports an optional `--template` for `--render-template`:

- `./generate-fbc.sh --render-template v4.20` — uses `v4.20/catalog-template.json` (default).
- `./generate-fbc.sh --render-template v4.20 --template catalog-template-dry-run.json` — uses the dry-run template. Use `v4.21` or `v4.22` for those OCP versions. Template can be a filename under the OCP fragment (e.g. `catalog-template-dry-run.json`) or an absolute path.

### Tekton pipelines

| File | Trigger | Output image |
|------|--------|--------------|
| `forklift-fbc-comp-stage-v420-dry-run-push.yaml` | Push of tag `fbc-dry-run/v4.20` | `.../forklift-fbc-stage-v420-dry-run:{{revision}}` |
| `forklift-fbc-comp-stage-v420-dry-run-pull-request.yaml` | Pull request targeting `stage` | `.../forklift-fbc-stage-v420-dry-run:on-pr-{{revision}}` |
| `forklift-fbc-comp-stage-v421-dry-run-push.yaml` | Push of tag `fbc-dry-run/v4.21` | `.../forklift-fbc-stage-v421-dry-run:{{revision}}` |
| `forklift-fbc-comp-stage-v421-dry-run-pull-request.yaml` | Pull request targeting `stage` | `.../forklift-fbc-stage-v421-dry-run:on-pr-{{revision}}` |
| `forklift-fbc-comp-stage-v422-dry-run-push.yaml` | Push of tag `fbc-dry-run/v4.22` | `.../forklift-fbc-stage-v422-dry-run:{{revision}}` |
| `forklift-fbc-comp-stage-v422-dry-run-pull-request.yaml` | Pull request targeting `stage` | `.../forklift-fbc-stage-v422-dry-run:on-pr-{{revision}}` |

**Workflow for push (tag):**

1. Pick the OCP version (e.g. `v4.20`, `v4.21`, or `v4.22`) and render: `./generate-fbc.sh --render-template v4.20 --template catalog-template-dry-run.json`
2. Commit that version’s catalog (e.g. `v4.20/catalog`) and any template changes
3. Push to `stage`, then create and push the matching tag: e.g. `git tag fbc-dry-run/v4.20 && git push origin fbc-dry-run/v4.20`
4. The corresponding push pipeline runs and builds the dry-run FBC image from the committed catalog.

**Workflow for PR:** Open a PR to `stage` with the relevant fragment’s catalog (e.g. `v4.21/catalog`) already rendered from the dry-run template. The PR pipelines will build the dry-run FBC images for each version that has committed catalog.

**Service account:** Each pipeline uses a version-specific SA, e.g. `build-pipeline-forklift-fbc-comp-stage-v420-dry-run`, `build-pipeline-forklift-fbc-comp-stage-v421-dry-run`, `build-pipeline-forklift-fbc-comp-stage-v422-dry-run`. Create these in the tenant namespace (or align with your existing FBC pipeline SAs) if your environment requires a dedicated SA per component.
