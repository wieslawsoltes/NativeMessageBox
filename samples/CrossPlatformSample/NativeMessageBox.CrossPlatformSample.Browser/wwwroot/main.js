import { dotnet } from './_framework/dotnet.js'

const is_browser = typeof window != "undefined";
if (!is_browser) throw new Error(`Expected to be running in a browser`);

async function ensureNativeMessageBoxBridge() {
    if (globalThis.NativeMessageBoxManaged) {
        return;
    }

    if (typeof document === "undefined") {
        throw new Error("Document is not available; unable to load native-message-box.js");
    }

    let bridgeUrl;
    try {
        if (typeof import.meta !== "undefined" && import.meta.url) {
            bridgeUrl = new URL("./native-message-box.js", import.meta.url).toString();
        }
    } catch {
        // ignore; fall back to document base
    }

    if (!bridgeUrl && typeof document !== "undefined") {
        const base = document.baseURI || (typeof window !== "undefined" ? window.location.href : "");
        if (base) {
            bridgeUrl = new URL("native-message-box.js", base).toString();
        }
    }

    if (!bridgeUrl) {
        bridgeUrl = "native-message-box.js";
    }

    await new Promise((resolve, reject) => {
        const script = document.createElement("script");
        script.src = bridgeUrl;
        script.async = false;
        script.onload = resolve;
        script.onerror = () => reject(new Error(`Failed to load native-message-box.js from ${bridgeUrl}`));
        document.head.append(script);
    });

    if (!globalThis.NativeMessageBoxManaged) {
        throw new Error(`NativeMessageBoxManaged bridge did not initialize after loading native-message-box.js from ${bridgeUrl}`);
    }
}

const dotnetRuntime = await dotnet
    .withDiagnosticTracing(false)
    .withApplicationArgumentsFromQuery()
    .create();

try {
    await ensureNativeMessageBoxBridge();
} catch (err) {
    console.error("NativeMessageBoxManaged bridge not loaded; ensure native-message-box.js is copied to wwwroot.", err);
    throw err;
}

const config = dotnetRuntime.getConfig();

await dotnetRuntime.runMain(config.mainAssemblyName, [globalThis.location.href]);
