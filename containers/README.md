# Containers

This directory holds development and validation container definitions.

## Files

- `dev.Dockerfile` — general-purpose development image for local validation, shell work, and CI-adjacent debugging.

## Usage

Build it from the repo root:

```bash
docker build -f containers/dev.Dockerfile -t linux-maint-dev .
```

Open a shell with the repo mounted:

```bash
docker run --rm -it -v "$PWD:/work" -w /work linux-maint-dev bash
```

This folder exists so future distro- or role-specific container definitions can live together instead of cluttering the repo root.

