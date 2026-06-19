# CI runner requirements (`darkflow-ci-gate`)

The `darkflow-ci-gate` workflow runs on a **self-hosted runner** and executes your
project's real checks (`pnpm install` / `pnpm lint` / `pnpm test`, or `ruff` /
`pytest`). It deliberately does **not** download a toolchain at job time — so the
runner must already have on `PATH`:

- **JS/TS repos:** `node` + `pnpm` (or `npm`)
- **Python repos:** `python3` + `pip`

## Containerised runners (myoung34/github-runner)

The stock `myoung34/github-runner` image ships **neither node nor pnpm**. With it
you get `pnpm: command not found` and the job fails at the first check. Bootstrapping
the toolchain at runtime (`actions/setup-node`, `pnpm/action-setup`) does **not**
work inside that minimal container either — there's no hosted tool cache to extract
into, so the setup step itself fails before any check runs.

**Fix: bake the toolchain into the runner image.** Example `Dockerfile`:

```dockerfile
FROM myoung34/github-runner:latest
ARG NODE_MAJOR=22
ARG PNPM_VERSION=10
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && corepack enable && corepack prepare "pnpm@${PNPM_VERSION}" --activate \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && node --version && pnpm --version
```

Point each runner service at this image (build once, reuse via a compose anchor):

```yaml
x-runner: &runner
  build: { context: . }
  image: darkflow-runner:node22
  restart: always
services:
  runner-myrepo:
    <<: *runner
    environment:
      RUNNER_NAME: myrepo-coolify
      ACCESS_TOKEN: '${GH_PAT}'
      REPO_URL: 'https://github.com/me/myrepo'
      RUNNER_SCOPE: repo
      LABELS: 'self-hosted,linux,x64'
```

Rebuild + restart: `docker compose up -d --build`. node + pnpm now sit on the
default `PATH` inside the container, so the gate works with plain `pnpm` calls.
