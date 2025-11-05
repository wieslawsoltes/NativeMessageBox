# Release and Maintenance Policy

## Versioning Strategy
- Semantic Versioning (`MAJOR.MINOR.PATCH`).
- Patch releases for bug fixes; minor releases for additive, backward-compatible features.
- Major releases reserved for breaking changes.
- Versions derived automatically via Nerdbank.GitVersioning tags (`vX.Y.Z`).

## Changelog
- Maintain a `CHANGELOG.md` (future task) summarizing notable changes per release.
- Each PR should include release notes if applicable.

## Release Process
1. Ensure CI is green on `main`.
2. Update documentation and changelog.
3. Tag commit (`git tag vX.Y.Z` and push).
4. Release workflow (`.github/workflows/release.yml`) builds packages and uploads artifacts to GitHub Releases.
5. Publish NuGet package to nuget.org (manual step pending automation).

## Support & Maintenance
- Target active support for latest minor release.
- Security fixes backported to previous minor when feasible.

## Issue Management
- Bug reports triaged weekly.
- Feature requests evaluated monthly; roadmap updates documented in `docs/project-plan.md`.

