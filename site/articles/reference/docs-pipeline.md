---
title: "Docs Pipeline"
---

# Docs Pipeline

This repository uses Lunet for the documentation site, following the same overall model as the TreeDataGrid project.

## Source Layout

| Path | Purpose |
| --- | --- |
| `site/config.scriban` | Lunet site configuration and API plugin setup |
| `site/menu.yml` | Top navigation |
| `site/articles` | Handwritten documentation content |
| `site/.lunet/css` | Site styling overrides and precompiled template CSS |
| `site/.lunet/layouts` | API layout overrides |

## Local Commands

```bash
./build-docs.sh
./check-docs.sh
./serve-docs.sh
```

PowerShell equivalents are available for `build-docs` and `serve-docs`.

## Output

Lunet writes the generated site to:

```text
site/.lunet/build/www
```

## CI Publishing

- Pull requests and branch builds validate the docs build in CI.
- The dedicated docs workflow publishes the generated site to GitHub Pages.

## Related

- [Documentation home](../readme.md)
- [API Documentation](../../api)
