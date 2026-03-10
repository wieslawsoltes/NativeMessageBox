---
title: "Samples"
---

# Samples

The repository includes several sample applications for validating different integration paths.

## Sample Inventory

| Sample | Purpose |
| --- | --- |
| `samples/Showcase` | Desktop-first feature coverage and quick manual validation |
| `samples/DialogPlayground` | Interactive sandbox for trying different options and result flows |
| `samples/CrossPlatformSample` | Desktop, Android, iOS, and browser packaging example |

## Build the Sample Solution

```bash
dotnet build samples/AvaloniaSamples.sln
```

## Run Desktop Samples

```bash
./samples/run-showcase.sh
./samples/run-playground.sh
```

On Windows, use the corresponding PowerShell scripts instead.

## Browser Sample

```bash
dotnet publish samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Browser -c Release
```

If you want the native browser runtime package regenerated first, run `./build/scripts/package-wasm.sh` before publishing.

## What to Validate

- Button result mapping
- Timeout handling
- Input and secondary content behavior
- Platform-specific fallbacks and log output

## Related

- [Browser Deployment](browser-deployment.md)
- [Troubleshooting](troubleshooting.md)
