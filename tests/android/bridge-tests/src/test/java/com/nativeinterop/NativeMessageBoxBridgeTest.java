package com.nativeinterop;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.lang.reflect.Method;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.After;
import org.junit.Test;
import org.robolectric.annotation.Config;

@Config(manifest = Config.NONE)
public class NativeMessageBoxBridgeTest {

    @After
    public void tearDown() {
        NativeMessageBoxBridge.clearTestCallback();
    }

    @Test
    public void notifyCompletedInvokesCallback() throws Exception {
        AtomicBoolean completed = new AtomicBoolean(false);
        AtomicBoolean wasCancelled = new AtomicBoolean(false);
        AtomicInteger buttonId = new AtomicInteger(0);

        NativeMessageBoxBridge.setTestCallback(new NativeMessageBoxBridge.TestCallback() {
            @Override
            public void onCompleted(long id, boolean cancelled) {
                completed.set(true);
                wasCancelled.set(cancelled);
                buttonId.set((int) id);
            }

            @Override
            public void onError(int errorCode) {
                throw new AssertionError("Unexpected error callback: " + errorCode);
            }
        });

        Method notifyCompleted = NativeMessageBoxBridge.class
                .getDeclaredMethod("notifyCompleted", long.class, long.class, boolean.class);
        notifyCompleted.setAccessible(true);

        notifyCompleted.invoke(null, 123L, 456L, true);

        assertTrue("Callback not invoked", completed.get());
        assertTrue("Cancel flag not propagated", wasCancelled.get());
        assertEquals("Button id mismatch", 456, buttonId.get());
    }

    @Test
    public void notifyErrorInvokesCallback() throws Exception {
        AtomicBoolean errored = new AtomicBoolean(false);
        AtomicInteger code = new AtomicInteger(0);

        NativeMessageBoxBridge.setTestCallback(new NativeMessageBoxBridge.TestCallback() {
            @Override
            public void onCompleted(long buttonId, boolean cancelled) {
                throw new AssertionError("Unexpected completion");
            }

            @Override
            public void onError(int errorCode) {
                errored.set(true);
                code.set(errorCode);
            }
        });

        Method notifyError = NativeMessageBoxBridge.class
                .getDeclaredMethod("notifyError", long.class, int.class);
        notifyError.setAccessible(true);

        notifyError.invoke(null, 42L, 7);

        assertTrue("Error callback not invoked", errored.get());
        assertEquals("Error code mismatch", 7, code.get());
    }
}
