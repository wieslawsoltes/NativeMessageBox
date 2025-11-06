using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;

namespace NativeMessageBox.Interop;

internal static class NativeLibraryLoader
{
    private const string LibraryBaseName = "nativemessagebox";
    private static readonly OSPlatform s_iosPlatform = OSPlatform.Create("IOS");
    private static readonly OSPlatform s_tvosPlatform = OSPlatform.Create("TVOS");
    private static readonly OSPlatform s_macCatalystPlatform = OSPlatform.Create("MACCATALYST");
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
        if (!string.IsNullOrWhiteSpace(runtimeId) && !ContainsRid(rids, runtimeId))
        {
            rids.Add(runtimeId);
        }

        var arch = RuntimeInformation.ProcessArchitecture.ToString().ToLowerInvariant();
        var platformPrefix = GetPlatformRidPrefix(runtimeId);

        if (!string.IsNullOrEmpty(platformPrefix))
        {
            var platformRid = $"{platformPrefix}-{arch}";
            if (!ContainsRid(rids, platformRid))
            {
                rids.Add(platformRid);
            }

            if (!ContainsRid(rids, platformPrefix))
            {
                rids.Add(platformPrefix);
            }

            if (platformPrefix.Equals("iossimulator", StringComparison.OrdinalIgnoreCase))
            {
                if (!ContainsRid(rids, "ios"))
                {
                    rids.Add("ios");
                }
            }
            else if (platformPrefix.Equals("ios", StringComparison.OrdinalIgnoreCase))
            {
                if (!ContainsRid(rids, "iossimulator"))
                {
                    rids.Add("iossimulator");
                }
            }

            if (platformPrefix.Equals("maccatalyst", StringComparison.OrdinalIgnoreCase))
            {
                if (!ContainsRid(rids, "osx"))
                {
                    rids.Add("osx");
                }
            }
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
            Path.Combine("..", "..", "..", "..", "..", "src", "native", "windows"),
            Path.Combine("..", "..", "..", "..", "..", "src", "native", "android"),
            Path.Combine("..", "..", "..", "..", "..", "src", "native", "ios"),
            Path.Combine("..", "..", "..", "..", "..", "artifacts", "android", "jni", "arm64-v8a"),
            Path.Combine("..", "..", "..", "..", "..", "artifacts", "android", "jni", "armeabi-v7a"),
            Path.Combine("..", "..", "..", "..", "..", "artifacts", "android", "jni", "x86_64")
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

    private static string GetPlatformRidPrefix(string runtimeIdentifier)
    {
        if (!string.IsNullOrEmpty(runtimeIdentifier))
        {
            if (runtimeIdentifier.StartsWith("iossimulator", StringComparison.OrdinalIgnoreCase))
            {
                return "iossimulator";
            }

            if (runtimeIdentifier.StartsWith("ios", StringComparison.OrdinalIgnoreCase))
            {
                return "ios";
            }

            if (runtimeIdentifier.StartsWith("tvossimulator", StringComparison.OrdinalIgnoreCase))
            {
                return "tvossimulator";
            }

            if (runtimeIdentifier.StartsWith("tvos", StringComparison.OrdinalIgnoreCase))
            {
                return "tvos";
            }

            if (runtimeIdentifier.StartsWith("maccatalyst", StringComparison.OrdinalIgnoreCase))
            {
                return "maccatalyst";
            }

            if (runtimeIdentifier.StartsWith("android", StringComparison.OrdinalIgnoreCase))
            {
                return "android";
            }

            if (runtimeIdentifier.StartsWith("osx", StringComparison.OrdinalIgnoreCase))
            {
                return "osx";
            }

            if (runtimeIdentifier.StartsWith("win", StringComparison.OrdinalIgnoreCase))
            {
                return "win";
            }

            if (runtimeIdentifier.StartsWith("linux", StringComparison.OrdinalIgnoreCase))
            {
                return "linux";
            }
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return "win";
        }

        if (IsPlatform(s_macCatalystPlatform))
        {
            return "maccatalyst";
        }

        if (IsPlatform(s_iosPlatform))
        {
            return "ios";
        }

        if (OperatingSystem.IsAndroid())
        {
            return "android";
        }

        if (IsPlatform(s_tvosPlatform))
        {
            return "tvos";
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            return "osx";
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        {
            return "linux";
        }

        return "linux";
    }

    private static string GetLibraryFileName()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return "nativemessagebox.dll";
        }

        if (IsApplePlatform())
        {
            return "libnativemessagebox.dylib";
        }

        return "libnativemessagebox.so";
    }

    private static bool IsApplePlatform()
    {
        return RuntimeInformation.IsOSPlatform(OSPlatform.OSX)
               || IsPlatform(s_iosPlatform)
               || IsPlatform(s_tvosPlatform)
               || IsPlatform(s_macCatalystPlatform);
    }

    private static bool IsPlatform(OSPlatform platform)
    {
        try
        {
            return RuntimeInformation.IsOSPlatform(platform);
        }
        catch (PlatformNotSupportedException)
        {
            return false;
        }
    }

    private static IEnumerable<string> GetCandidatePaths(Assembly assembly)
    {
        var assemblyDirectory = Path.GetDirectoryName(assembly.Location) ?? AppContext.BaseDirectory;
        var libraryFileName = GetLibraryFileName();

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
