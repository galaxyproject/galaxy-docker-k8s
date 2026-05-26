# Externalizing the Galaxy container build into `galaxy-docker-k8s`

Moves ~1,700 lines of build/publish orchestration out of `galaxyproject/galaxy`'s
CI and into `galaxyproject/galaxy-docker-k8s` (which already owns the ansible
playbook the image is built from). The main repo keeps **one ~50-line file** whose
only job is to say "source moved".

## File layout

```
galaxyproject/galaxy
  .github/workflows/notify-container-build.yml   # the only thing that stays in-repo

galaxyproject/galaxy-docker-k8s
  .k8s_ci.Dockerfile            # OPTIONAL: see "Where the Dockerfile lives" below
  .github/workflows/
    build-test.yml              # reusable: checkout galaxy@ref, build once, smoke-test, optionally publish
    on-source-changed.yml       # entry point: fired by the dispatch hook (and manually)
    nightly.yml                 # cron safety net: reconcile :dev + changed release_* branches
```

## Trigger model

| Event in galaxy/galaxy | Hook sends `build_type` | Image tag | Publishes | Helm PR |
|---|---|---|---|---|
| push to `dev`          | `dev`            | `dev`         | ✅ | — |
| push to `release_*`    | `release_branch` | `<X>-auto`    | ✅ | — |
| release (published)    | `release`        | `<version>`   | ✅ | ✅ (non-prerelease) |
| nightly cron           | — (cron)         | `dev` + `<X>-auto` | ✅ | — |

`dev` is published on every green dev build here (simpler than the PR's
"test-on-push, publish-nightly" split). If you prefer the old behaviour, set
`publish: false` for the `dev` build_type in `on-source-changed.yml` and let
`nightly.yml` be the only thing that publishes `:dev`.

## Secrets to move to `galaxy-docker-k8s`

Lift these from galaxy/galaxy → galaxy-docker-k8s repo secrets:

- `QUAY_USERNAME`, `QUAY_PASSWORD`
- `DOCKERHUB_USERNAME`, `DOCKERHUB_PASSWORD`
- `K8S_SLACK_WEBHOOK_URL`
- `HELM_UPDATER_APP_ID`, `HELM_UPDATER_PKEY`  (GitHub App with access to `galaxy-helm`)

New secret in **galaxy/galaxy**:

- `CONTAINER_BUILD_DISPATCH_TOKEN` — fine-grained PAT **or** GitHub App token with
  `Contents: read` on `galaxyproject/galaxy-docker-k8s`. The built-in
  `GITHUB_TOKEN` **cannot** dispatch across repos.

## Where the Dockerfile lives

`.k8s_ci.Dockerfile` is the one artifact coupled to the Galaxy source layout (it
`rm -rf`s specific paths, stages the client build, etc.). Two options:

1. **Keep it in galaxy/galaxy (recommended).** `build-test.yml` checks out
   galaxy@ref and builds with that checkout's Dockerfile, so layout changes stay
   atomic with the code that caused them. This is what the drafts assume.
2. Move it to galaxy-docker-k8s. Lower main-repo footprint, but a source-layout
   change in galaxy can now break the build out-of-band. The nightly dev build
   catches such drift within a day, but option 1 is safer.

## Migration order

1. Create the secrets above in both repos.
2. Land the three workflows in `galaxy-docker-k8s`. Test with **workflow_dispatch**
   (`on-source-changed.yml` → build_type=dev, ref=dev) before wiring the hook.
3. Land `notify-container-build.yml` in galaxy/galaxy.
4. **Delete** `build_container_image.yaml` (and PR #22763's four new files) from
   galaxy/galaxy. The "off switch" is now `git rm`, not a manual GitHub-UI toggle.
5. Update the helm/quay/dockerhub README pointers to note the build now lives in
   galaxy-docker-k8s.

## What this fixes vs PR #22763

- **One build instead of two/three.** The image is built once and passed between
  jobs as an artifact; smoke-test and publish reuse the exact bytes that were tested.
- **Fixes a latent bug.** PR #22763's `container_build_test.yml` smoke-test job runs
  `docker save galaxy/galaxy-min:<tag>` on a runner that never built the image
  (build + smoke are separate runners with separate Docker daemons) — that `save`
  has nothing to save. Artifact passing makes the tested image actually present.
- **`IMAGE_TAG` baked correctly.** Built once with the real tag, so the
  `/api/version` `image_tag` and the OCI `version` label match what's published
  (the PR builds the smoke image with a throwaway `test` tag).
- **No manual disable step.** Removing the build is a deletion in git history.
