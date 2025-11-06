package com.nativeinterop;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.os.Handler;
import android.os.Looper;

public final class NativeMessageBoxBridge {
    private NativeMessageBoxBridge() {
    }

    private static volatile TestCallback sTestCallback;

    public interface TestCallback {
        void onCompleted(long buttonId, boolean cancelled);
        void onError(int errorCode);
    }

    public static void setTestCallback(TestCallback callback) {
        sTestCallback = callback;
    }

    public static void clearTestCallback() {
        sTestCallback = null;
    }

    public static void showMessageDialog(
            final Activity activity,
            final long nativeHandle,
            final String title,
            final String message,
            final String[] buttonLabels,
            final long[] buttonIds,
            final int cancelIndex,
            final boolean cancellable) {

        if (activity == null) {
            nativeOnDialogError(nativeHandle, 3); // NMB_E_PLATFORM_FAILURE
            return;
        }

        final Handler handler = new Handler(Looper.getMainLooper());
        handler.post(() -> {
            try {
                final AlertDialog.Builder builder = new AlertDialog.Builder(activity);
                if (title != null && !title.isEmpty()) {
                    builder.setTitle(title);
                }
                builder.setMessage(message != null ? message : "");

                final int count = buttonLabels != null ? buttonLabels.length : 0;
                final DialogInterface.OnClickListener listener = (dialog, which) -> {
                    final int index = mapWhichToIndex(which, count);
                    final long buttonId = resolveButtonId(index, buttonIds);
                    notifyCompleted(nativeHandle, buttonId, false);
                };

                if (count >= 1) {
                    builder.setPositiveButton(buttonLabels[0], listener);
                }

                if (count >= 2) {
                    builder.setNegativeButton(buttonLabels[1], listener);
                }

                if (count >= 3) {
                    builder.setNeutralButton(buttonLabels[2], listener);
                }

                builder.setCancelable(cancellable);

                final AlertDialog dialog = builder.create();
                dialog.setCanceledOnTouchOutside(cancellable);
                dialog.setOnCancelListener(d -> {
                    final long buttonId = resolveButtonId(cancelIndex, buttonIds);
                    notifyCompleted(nativeHandle, buttonId, true);
                });
                dialog.show();
            } catch (Throwable t) {
                notifyError(nativeHandle, 3);
            }
        });
    }

    private static long resolveButtonId(int index, long[] buttonIds) {
        if (buttonIds == null || index < 0 || index >= buttonIds.length) {
            return 0L;
        }

        return buttonIds[index];
    }

    private static int mapWhichToIndex(int which, int buttonCount) {
        if (buttonCount <= 0) {
            return -1;
        }

        switch (which) {
            case AlertDialog.BUTTON_POSITIVE:
                return 0;
            case AlertDialog.BUTTON_NEGATIVE:
                return buttonCount > 1 ? 1 : 0;
            case AlertDialog.BUTTON_NEUTRAL:
                return buttonCount > 2 ? 2 : (buttonCount - 1);
            default:
                return -1;
        }
    }

    private static native void nativeOnDialogCompleted(long handle, long buttonId, boolean cancelled);

    private static native void nativeOnDialogError(long handle, int errorCode);

    private static void notifyCompleted(long handle, long buttonId, boolean cancelled) {
        nativeOnDialogCompleted(handle, buttonId, cancelled);
        final TestCallback callback = sTestCallback;
        if (callback != null) {
            callback.onCompleted(buttonId, cancelled);
        }
    }

    private static void notifyError(long handle, int errorCode) {
        nativeOnDialogError(handle, errorCode);
        final TestCallback callback = sTestCallback;
        if (callback != null) {
            callback.onError(errorCode);
        }
    }
}
