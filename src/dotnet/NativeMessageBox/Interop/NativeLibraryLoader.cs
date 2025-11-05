using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;

namespace NativeMessageBox.Interop;

internal static class NativeLibraryLoader
{
    private const string LibraryBaseName = "nativemessagebox";
    private static readonly List<string> s_probingPaths = new();
    private static readonly object s_sync = new();

    internal static void RegisterProbingPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return;
        }

        lock (s_sync)
        {
            if (!s_probingPaths.Contains(path))
            {
                s_probingPaths.Add(path);
            }
        }
    }

    internal static IntPtr Resolve(string libraryName, Assembly assembly, DllImportSearchPath? searchPath)
    {
        if (!string.Equals(libraryName, LibraryBaseName, StringComparison.Ordinal))
        {
            return IntPtr.Zero;
        }

        foreach (var candidate in GetCandidatePaths(assembly))
        {
            if (NativeLibrary.TryLoad(candidate, out var handle))
            {
                return handle;
            }
        }

        return IntPtr.Zero;
    }

    internal static IReadOnlyList<string> GetRuntimeFallbacks()
    {
        var rids = new List<string>();
        var runtimeId = RuntimeInformation.RuntimeIdentifier;
        rids.Add(runtimeId);

        string platformRidPrefix;
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            platformRidPrefix = "win";
        }
        else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            platformRidPrefix = "osx";
        }
        else
        {
            platformRidPrefix = "linux";
        }

        var arch = RuntimeInformation.ProcessArchitecture.ToString().ToLowerInvariant();
        var platformRid = $"{platformRidPrefix}-{arch}";

        if (!ContainsRid(rids, platformRid))
        {
            rids.Add(platformRid);
        }

        if (!ContainsRid(rids, platformRidPrefix))
        {
            rids.Add(platformRidPrefix);
        }

        return rids;
    }

    internal static void RegisterDevelopmentProbingPaths()
    {
        var baseDir = AppContext.BaseDirectory;

        string[] relativeCandidates =
        {
            Path.Combine("..", "..", "..", "..", "..", "build", "native", "src", "native"),
            Path.Combine("..", "..", "..", "..", "..", "src", "native", "macos"),
            Path.Combine("..", "..", "..", "..", "..", "src", "native", "linux"),
            Path.Combine("..", "..", "..", "..", "..", "src", "native", "windows")
        };

        foreach (var relative in relativeCandidates)
        {
            var fullPath = Path.GetFullPath(Path.Combine(baseDir, relative));
            if (Directory.Exists(fullPath))
            {
                RegisterProbingPath(fullPath);
            }
        }
    }

    private static bool ContainsRid(List<string> list, string value)
    {
        foreach (var item in list)
        {
            if (string.Equals(item, value, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static IEnumerable<string> GetCandidatePaths(Assembly assembly)
    {
        var assemblyDirectory = Path.GetDirectoryName(assembly.Location) ?? AppContext.BaseDirectory;
        var libraryFileName = RuntimeInformation.IsOSPlatform(OSPlatform.Windows)
            ? "nativemessagebox.dll"
            : RuntimeInformation.IsOSPlatform(OSPlatform.OSX)
                ? "libnativemessagebox.dylib"
                : "libnativemessagebox.so";

        var envPath = Environment.GetEnvironmentVariable("NMB_NATIVE_PATH");
        if (!string.IsNullOrWhiteSpace(envPath))
        {
            yield return Path.Combine(envPath, libraryFileName);
        }

        lock (s_sync)
        {
            foreach (var path in s_probingPaths)
            {
                yield return Path.Combine(path, libraryFileName);
            }
        }

        yield return Path.Combine(assemblyDirectory, libraryFileName);

        foreach (var rid in GetRuntimeFallbacks())
        {
            yield return Path.Combine(assemblyDirectory, "runtimes", rid, "native", libraryFileName);
        }
    }
}
