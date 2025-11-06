package com.nativeinterop;

import org.robolectric.annotation.Implementation;
import org.robolectric.annotation.Implements;

@Implements(NativeMessageBoxBridge.class)
public final class NativeMessageBoxBridgeShadow {

    private NativeMessageBoxBridgeShadow() {
    }

    @Implementation
    protected static void nativeOnDialogCompleted(long handle, long buttonId, boolean cancelled) {
        // No-op: prevent JNI call in local unit tests.
    }

    @Implementation
    protected static void nativeOnDialogError(long handle, int errorCode) {
        // No-op: prevent JNI call in local unit tests.
    }
}
