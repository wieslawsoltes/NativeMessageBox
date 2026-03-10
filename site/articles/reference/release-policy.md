---
title: "Release Policy"
---

# Release Policy

## Versioning

- Semantic Versioning (`MAJOR.MINOR.PATCH`)
- Patch releases for fixes
- Minor releases for additive features
- Major releases for breaking ABI or API changes

## Release Flow

1. Keep `main` green.
2. Update docs and release notes.
3. Tag the release with `vX.Y.Z`.
4. Let the release workflow build and publish artifacts.

## Maintenance Priorities

- Keep the public ABI stable unless a major release is intentional.
- Keep runtime packaging consistent across RIDs.
- Document platform behavior changes before shipping them.

## Related

- [Docs Pipeline](docs-pipeline.md)
- [Roadmap](roadmap.md)
