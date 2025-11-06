(function () {
  if (typeof Module === "undefined") {
    Module = {};
  }

  const ResultCode = {
    OK: 0,
    INVALID_ARGUMENT: 1,
    UNINITIALIZED: 2,
    NOT_SUPPORTED: 3,
    PLATFORM_FAILURE: 4,
    CANCELLED: 5,
    OUT_OF_MEMORY: 6
  };

  const InputMode = {
    NONE: 0,
    CHECKBOX: 1,
    TEXT: 2,
    PASSWORD: 3,
    COMBO: 4
  };

  Module.NmbResultCode = ResultCode;
  Module.NmbInputMode = InputMode;

  function ensureStyles() {
    if (typeof document === "undefined") {
      return;
    }

    if (document.getElementById("nmb-dialog-styles")) {
      return;
    }

    const style = document.createElement("style");
    style.id = "nmb-dialog-styles";
    style.textContent = `
.nmb-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 99999;
  backdrop-filter: blur(2px);
}
.nmb-dialog {
  min-width: min(480px, 90vw);
  max-width: min(600px, 92vw);
  background: var(--nmb-dialog-bg, #1f1f1f);
  color: var(--nmb-dialog-fg, #f0f0f0);
  box-shadow: 0 24px 48px rgba(0, 0, 0, 0.35);
  border-radius: 12px;
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
.nmb-dialog[dir="rtl"] {
  direction: rtl;
}
.nmb-dialog-title {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 0;
}
.nmb-dialog-body {
  display: flex;
  gap: 16px;
}
.nmb-dialog-icon {
  flex-shrink: 0;
  width: 40px;
  height: 40px;
}
.nmb-dialog-message {
  margin: 0;
  white-space: pre-wrap;
  word-break: break-word;
}
.nmb-dialog-secondary {
  font-size: 0.9rem;
  opacity: 0.8;
}
.nmb-dialog-footer {
  display: flex;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 8px;
}
.nmb-dialog-footer button {
  min-width: 88px;
  padding: 8px 14px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.15);
  background: rgba(255, 255, 255, 0.08);
  color: inherit;
  font: inherit;
  cursor: pointer;
}
.nmb-dialog-footer button[data-kind="primary"] {
  background: var(--nmb-primary-bg, #2563eb);
  border-color: transparent;
  color: #ffffff;
}
.nmb-dialog-footer button[data-kind="destructive"] {
  background: #b91c1c;
  color: #ffffff;
}
.nmb-dialog-footer button:focus-visible {
  outline: 2px solid var(--nmb-focus, #38bdf8);
  outline-offset: 2px;
}
.nmb-dialog-controls {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.nmb-dialog-checkbox {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.95rem;
}
.nmb-dialog-input {
  padding: 8px 10px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.25);
  background: rgba(0, 0, 0, 0.4);
  color: inherit;
  font: inherit;
}
.nmb-dialog-select {
  padding: 8px 10px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.25);
  background: rgba(0, 0, 0, 0.4);
  color: inherit;
  font: inherit;
}
@media (prefers-color-scheme: light) {
  .nmb-dialog {
    --nmb-dialog-bg: #ffffff;
    --nmb-dialog-fg: #111111;
  }
  .nmb-dialog-footer button {
    background: rgba(15, 23, 42, 0.06);
    color: inherit;
  }
  .nmb-dialog-input,
  .nmb-dialog-select {
    background: rgba(15, 23, 42, 0.03);
    border-color: rgba(15, 23, 42, 0.2);
  }
}
`;
    document.head.appendChild(style);
  }

  function detectDirection(locale) {
    if (!locale) {
      return "ltr";
    }

    const rtlLangs = ["ar", "fa", "he", "ku", "ps", "ur"];
    const tag = locale.toLowerCase().split(/[-_]/)[0];
    return rtlLangs.includes(tag) ? "rtl" : "ltr";
  }

  function fallbackPrompt(request) {
    const title = request.title ? request.title + "\n\n" : "";
    const message = request.message || "";
    const text = title + message;
    const buttons = request.buttons && request.buttons.length > 0
      ? request.buttons
      : [{ id: 1, label: "OK", isDefault: true, isCancel: false }];
    const primary = buttons.find(b => b.isDefault) || buttons[0];
    const secondary = buttons.find(b => b.isCancel) || buttons[1];

    return new Promise((resolve) => {
      const res = {
        resultCode: ResultCode.OK,
        buttonId: primary ? primary.id : 0,
        checkboxChecked: false,
        wasTimeout: false
      };

      if (typeof alert === "function" && buttons.length <= 1) {
        alert(text);
        resolve(res);
        return;
      }

      if (typeof confirm === "function" && buttons.length === 2) {
        const confirmed = confirm(text);
        res.buttonId = confirmed
          ? primary.id
          : (secondary ? secondary.id : primary.id);
        resolve(res);
        return;
      }

      console.warn("NativeMessageBox: browser fallback cannot represent requested dialog.");
      resolve({
        resultCode: ResultCode.NOT_SUPPORTED,
        buttonId: 0,
        checkboxChecked: false,
        wasTimeout: false
      });
    });
  }

  function createDefaultHost(ModuleInstance) {
    const supportsDom = typeof document !== "undefined" && typeof document.createElement === "function";
    let activeDialog = null;

    function teardownDialog(result) {
      if (!activeDialog) {
        return;
      }

      const { overlay, resolve, timer } = activeDialog;

      if (overlay && overlay.parentElement) {
        overlay.parentElement.removeChild(overlay);
      }

      if (timer) {
        clearTimeout(timer);
      }

      activeDialog = null;

      if (resolve) {
        resolve(result);
      }
    }

    function gatherInputValue(request, controls) {
      if (!controls) {
        return undefined;
      }

      if (controls.input) {
        if (request.input && request.input.mode === InputMode.CHECKBOX) {
          return controls.input.checked ? "true" : "false";
        }
        if (request.input && request.input.mode === InputMode.COMBO) {
          return controls.input.value;
        }

        return controls.input.value;
      }

      return undefined;
    }

    async function showMessageBox(request) {
      if (!supportsDom) {
        return fallbackPrompt(request);
      }

      if (activeDialog) {
        teardownDialog({
          resultCode: ResultCode.CANCELLED,
          buttonId: 0,
          checkboxChecked: false,
          wasTimeout: false
        });
      }

      ensureStyles();

      const locale = request.locale || (typeof navigator !== "undefined" ? navigator.language : "en-US");
      const overlay = document.createElement("div");
      overlay.className = "nmb-overlay";
      overlay.setAttribute("role", "presentation");
      overlay.tabIndex = -1;

      const dialog = document.createElement("div");
      dialog.className = "nmb-dialog";
      dialog.setAttribute("role", "dialog");
      dialog.setAttribute("aria-modal", "true");
      dialog.setAttribute("dir", detectDirection(locale));
      dialog.setAttribute("lang", locale);

      const title = document.createElement("h1");
      title.className = "nmb-dialog-title";
      title.textContent = request.title || "";
      dialog.appendChild(title);

      const body = document.createElement("div");
      body.className = "nmb-dialog-body";

      if (request.icon !== undefined && request.icon !== null) {
        const icon = document.createElement("div");
        icon.className = "nmb-dialog-icon";
        icon.setAttribute("aria-hidden", "true");
        icon.textContent = "";
        icon.dataset.icon = String(request.icon);
        body.appendChild(icon);
      }

      const message = document.createElement("div");
      message.className = "nmb-dialog-message";
      if (request.message) {
        const lines = request.message.split(/\r?\n/);
        lines.forEach((line, index) => {
          if (index > 0) {
            message.appendChild(document.createElement("br"));
          }
          message.appendChild(document.createTextNode(line));
        });
      }
      body.appendChild(message);
      dialog.appendChild(body);

      const controlsContainer = document.createElement("div");
      controlsContainer.className = "nmb-dialog-controls";
      let inputControl = null;
      let verificationControl = null;

      if (request.input && request.input.mode !== InputMode.NONE) {
        if (request.input.mode === InputMode.CHECKBOX) {
          const checkboxWrapper = document.createElement("label");
          checkboxWrapper.className = "nmb-dialog-checkbox";

          inputControl = document.createElement("input");
          inputControl.type = "checkbox";
          inputControl.className = "nmb-dialog-input";
          inputControl.checked = request.input.defaultValue === "true";

          const span = document.createElement("span");
          span.textContent = request.input.prompt || "";

          checkboxWrapper.appendChild(inputControl);
          checkboxWrapper.appendChild(span);
          controlsContainer.appendChild(checkboxWrapper);
        } else if (request.input.mode === InputMode.COMBO) {
          const label = document.createElement("label");
          label.textContent = request.input.prompt || "";

          inputControl = document.createElement("select");
          inputControl.className = "nmb-dialog-select";

          if (request.input.comboItems && request.input.comboItems.length > 0) {
            request.input.comboItems.forEach((item) => {
              const option = document.createElement("option");
              option.value = item;
              option.textContent = item;
              if (request.input.defaultValue && request.input.defaultValue === item) {
                option.selected = true;
              }
              inputControl.appendChild(option);
            });
          }

          label.appendChild(inputControl);
          controlsContainer.appendChild(label);
        } else {
          const label = document.createElement("label");
          label.textContent = request.input.prompt || "";

          inputControl = document.createElement("input");
          inputControl.type = request.input.mode === InputMode.PASSWORD ? "password" : "text";
          inputControl.className = "nmb-dialog-input";
          inputControl.placeholder = request.input.placeholder || "";
          if (request.input.defaultValue) {
            inputControl.value = request.input.defaultValue;
          }

          label.appendChild(inputControl);
          controlsContainer.appendChild(label);
        }
      }

      if (request.verificationText) {
        const checkboxWrapper = document.createElement("label");
        checkboxWrapper.className = "nmb-dialog-checkbox";

        verificationControl = document.createElement("input");
        verificationControl.type = "checkbox";
        verificationControl.className = "nmb-dialog-input";
        verificationControl.checked = false;

        const span = document.createElement("span");
        span.textContent = request.verificationText;

        checkboxWrapper.appendChild(verificationControl);
        checkboxWrapper.appendChild(span);
        controlsContainer.appendChild(checkboxWrapper);
      }

      if (controlsContainer.childNodes.length > 0) {
        dialog.appendChild(controlsContainer);
      }

      if (request.secondary) {
        const secondary = document.createElement("div");
        secondary.className = "nmb-dialog-secondary";
        const lines = [
          request.secondary.informativeText,
          request.secondary.footerText,
          request.secondary.expandedText
        ].filter(Boolean);
        secondary.textContent = lines.join("\n");
        if (lines.length > 0) {
          dialog.appendChild(secondary);
        }
      }

      const footer = document.createElement("div");
      footer.className = "nmb-dialog-footer";

      const buttons = (request.buttons && request.buttons.length > 0)
        ? request.buttons
        : [{ id: 1, label: "OK", isDefault: true, isCancel: false }];

      let defaultButton = buttons.find(b => b.isDefault) || buttons[0];
      const cancelButton = buttons.find(b => b.isCancel);

      const buttonElements = buttons.map((button) => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.textContent = button.label || "";
        btn.dataset.buttonId = String(button.id);
        btn.dataset.kind = button.kind === 1 ? "primary"
          : button.kind === 3 ? "destructive"
          : "default";

        btn.addEventListener("click", () => {
          teardownDialog({
            resultCode: ResultCode.OK,
            buttonId: button.id,
            checkboxChecked: verificationControl ? verificationControl.checked : false,
            wasTimeout: false,
            inputValue: gatherInputValue(request, { input: inputControl })
          });
        });

        footer.appendChild(btn);
        return btn;
      });

      dialog.appendChild(footer);
      overlay.appendChild(dialog);
      document.body.appendChild(overlay);

      const focusTarget = buttonElements.find(btn => btn.dataset.buttonId === String(defaultButton.id)) || buttonElements[0];
      if (focusTarget) {
        focusTarget.focus({ preventScroll: true });
      } else if (inputControl) {
        inputControl.focus({ preventScroll: true });
      }

      function handleKeyDown(event) {
        if (event.key === "Escape") {
          if (request.requiresExplicitAck || !request.allowEscape) {
            event.preventDefault();
            return;
          }

          if (cancelButton) {
            teardownDialog({
              resultCode: ResultCode.OK,
              buttonId: cancelButton.id,
              checkboxChecked: verificationControl ? verificationControl.checked : false,
              wasTimeout: false,
              inputValue: gatherInputValue(request, { input: inputControl })
            });
          } else {
            teardownDialog({
              resultCode: ResultCode.CANCELLED,
              buttonId: 0,
              checkboxChecked: verificationControl ? verificationControl.checked : false,
              wasTimeout: false,
              inputValue: undefined
            });
          }
        }

        if (event.key === "Tab" && buttonElements.length > 0) {
          const focusables = [];
          if (inputControl && inputControl.tabIndex !== -1) {
            focusables.push(inputControl);
          }
          if (verificationControl && verificationControl.tabIndex !== -1) {
            focusables.push(verificationControl);
          }
          buttonElements.forEach(btn => focusables.push(btn));

          if (focusables.length > 0) {
            const current = document.activeElement;
            const index = focusables.indexOf(current);
            let nextIndex = index;
            if (event.shiftKey) {
              nextIndex = index <= 0 ? focusables.length - 1 : index - 1;
            } else {
              nextIndex = index >= focusables.length - 1 ? 0 : index + 1;
            }

            focusables[nextIndex].focus({ preventScroll: true });
            event.preventDefault();
          }
        }
      }

      function handleOverlayClick(event) {
        if (request.requiresExplicitAck) {
          return;
        }

        if (event.target === overlay) {
          if (cancelButton) {
            teardownDialog({
              resultCode: ResultCode.OK,
              buttonId: cancelButton.id,
              checkboxChecked: verificationControl ? verificationControl.checked : false,
              wasTimeout: false,
              inputValue: gatherInputValue(request, { input: inputControl })
            });
          } else {
            teardownDialog({
              resultCode: ResultCode.CANCELLED,
              buttonId: 0,
              checkboxChecked: verificationControl ? verificationControl.checked : false,
              wasTimeout: false,
              inputValue: undefined
            });
          }
        }
      }

      overlay.addEventListener("keydown", handleKeyDown, true);
      overlay.addEventListener("click", handleOverlayClick);

      let timeoutId = null;
      if (request.timeoutMilliseconds && request.timeoutMilliseconds > 0) {
        timeoutId = setTimeout(() => {
          const timeoutButton = buttons.find(btn => btn.id === request.timeoutButtonId);
          if (timeoutButton) {
            teardownDialog({
              resultCode: ResultCode.OK,
              buttonId: timeoutButton.id,
              checkboxChecked: verificationControl ? verificationControl.checked : false,
              wasTimeout: true,
              inputValue: gatherInputValue(request, { input: inputControl })
            });
          } else if (cancelButton) {
            teardownDialog({
              resultCode: ResultCode.OK,
              buttonId: cancelButton.id,
              checkboxChecked: verificationControl ? verificationControl.checked : false,
              wasTimeout: true,
              inputValue: gatherInputValue(request, { input: inputControl })
            });
          } else {
            teardownDialog({
              resultCode: ResultCode.CANCELLED,
              buttonId: 0,
              checkboxChecked: verificationControl ? verificationControl.checked : false,
              wasTimeout: true,
              inputValue: undefined
            });
          }
        }, request.timeoutMilliseconds);
      }

      return new Promise((resolve) => {
        activeDialog = {
          overlay,
          resolve,
          timer: timeoutId
        };

        overlay.focus({ preventScroll: true });
      });
    }

    return {
      showMessageBox,
      shutdown() {
        if (activeDialog) {
          teardownDialog({
            resultCode: ResultCode.CANCELLED,
            buttonId: 0,
            checkboxChecked: false,
            wasTimeout: false
          });
        }
      }
    };
  }

  if (!Module.nmbCreateMessageBoxInterop) {
    Module.nmbCreateMessageBoxInterop = function (ModuleInstance) {
      const HEAPU32 = ModuleInstance.HEAPU32;
      const utf8ToString = ModuleInstance.UTF8ToString;
      const stringToUTF8 = ModuleInstance.stringToUTF8;
      const lengthBytesUTF8 = ModuleInstance.lengthBytesUTF8;
      const malloc = ModuleInstance._malloc;

      const BUTTON_WORDS = 6;
      const INPUT_WORDS = 6;
      const SECONDARY_WORDS = 4;
      const REQUEST_WORDS = 16;
      const RESPONSE_WORDS = 6;

      let host = null;

      function readOptionalString(ptr) {
        return ptr ? utf8ToString(ptr) : undefined;
      }

      function readButtons(ptr, count) {
        if (!ptr || count === 0) {
          return [];
        }

        const out = [];
        let base = ptr >> 2;
        for (let i = 0; i < count; i += 1) {
          const idx = base + i * BUTTON_WORDS;
          out.push({
            id: HEAPU32[idx],
            kind: HEAPU32[idx + 1],
            isDefault: !!HEAPU32[idx + 2],
            isCancel: !!HEAPU32[idx + 3],
            label: readOptionalString(HEAPU32[idx + 4]),
            description: readOptionalString(HEAPU32[idx + 5])
          });
        }

        return out;
      }

      function readInput(ptr) {
        if (!ptr) {
          return null;
        }

        const base = ptr >> 2;
        const mode = HEAPU32[base];
        const comboPtr = HEAPU32[base + 4];
        const comboCount = HEAPU32[base + 5];
        const comboItems = [];
        if (comboPtr && comboCount > 0) {
          const comboBase = comboPtr >> 2;
          for (let i = 0; i < comboCount; i += 1) {
            const value = readOptionalString(HEAPU32[comboBase + i]);
            comboItems.push(value !== undefined ? value : "");
          }
        }

        return {
          mode,
          prompt: readOptionalString(HEAPU32[base + 1]),
          placeholder: readOptionalString(HEAPU32[base + 2]),
          defaultValue: readOptionalString(HEAPU32[base + 3]),
          comboItems
        };
      }

      function readSecondary(ptr) {
        if (!ptr) {
          return null;
        }

        const base = ptr >> 2;
        return {
          informativeText: readOptionalString(HEAPU32[base]),
          expandedText: readOptionalString(HEAPU32[base + 1]),
          footerText: readOptionalString(HEAPU32[base + 2]),
          helpLink: readOptionalString(HEAPU32[base + 3])
        };
      }

      function readRequest(ptr) {
        const base = ptr >> 2;
        const buttonsPtr = HEAPU32[base + 2];
        const buttonCount = HEAPU32[base + 3];
        const verificationTextPtr = HEAPU32[base + 7];
        const showSuppress = !!HEAPU32[base + 9];

        return {
          title: readOptionalString(HEAPU32[base + 0]),
          message: readOptionalString(HEAPU32[base + 1]),
          buttons: readButtons(buttonsPtr, buttonCount),
          icon: HEAPU32[base + 4],
          severity: HEAPU32[base + 5],
          modality: HEAPU32[base + 6],
          verificationText: showSuppress ? readOptionalString(verificationTextPtr) : undefined,
          allowEscape: !!HEAPU32[base + 8],
          showSuppressCheckbox: showSuppress,
          requiresExplicitAck: !!HEAPU32[base + 10],
          timeoutMilliseconds: HEAPU32[base + 11],
          timeoutButtonId: HEAPU32[base + 12],
          locale: readOptionalString(HEAPU32[base + 13]),
          input: readInput(HEAPU32[base + 14]),
          secondary: readSecondary(HEAPU32[base + 15])
        };
      }

      function writeResponse(ptr, result) {
        const base = ptr >> 2;
        const { resultCode, buttonId, checkboxChecked, wasTimeout, inputValue } = result;

        HEAPU32[base + 0] = resultCode >>> 0;
        HEAPU32[base + 1] = buttonId >>> 0;
        HEAPU32[base + 2] = checkboxChecked ? 1 : 0;
        HEAPU32[base + 3] = wasTimeout ? 1 : 0;
        HEAPU32[base + 4] = 0;
        HEAPU32[base + 5] = 0;

        if (typeof inputValue === "string") {
          const length = lengthBytesUTF8(inputValue) + 1;
          const mem = malloc(length);
          if (!mem) {
            HEAPU32[base + 0] = ResultCode.OUT_OF_MEMORY;
            return;
          }

          stringToUTF8(inputValue, mem, length);
          HEAPU32[base + 4] = mem;
          HEAPU32[base + 5] = length - 1;
        }
      }

      async function dispatch(ptrRequest, ptrResponse) {
        const configuredHost = ModuleInstance.nativeMessageBox;
        if (configuredHost && configuredHost !== host) {
          host = configuredHost;
        }

        if (!host) {
          host = createDefaultHost(ModuleInstance);
          ModuleInstance.nativeMessageBox = host;
        }

        const request = readRequest(ptrRequest);

        let result;
        try {
          const hostFunc = host && typeof host.showMessageBox === "function"
            ? host.showMessageBox.bind(host)
            : null;

          if (!hostFunc) {
            console.warn("NativeMessageBox: host missing showMessageBox implementation, using fallback.");
            result = await createDefaultHost(ModuleInstance).showMessageBox(request);
          } else {
            result = await hostFunc(request, { Module: ModuleInstance, ResultCode, InputMode });
          }
        } catch (err) {
          console.error("NativeMessageBox: host threw an error.", err);
          result = {
            resultCode: ResultCode.PLATFORM_FAILURE,
            buttonId: 0,
            checkboxChecked: false,
            wasTimeout: false
          };
        }

        if (!result || typeof result !== "object") {
          result = {
            resultCode: ResultCode.PLATFORM_FAILURE,
            buttonId: 0,
            checkboxChecked: false,
            wasTimeout: false
          };
        }

        if (typeof result.resultCode !== "number") {
          result.resultCode = ResultCode.OK;
        }

        if (typeof result.buttonId !== "number") {
          const defaultButton = request.buttons && request.buttons.find(b => b.isDefault);
          result.buttonId = defaultButton ? defaultButton.id : 0;
        }

        if (result.checkboxChecked === undefined) {
          result.checkboxChecked = false;
        }

        if (result.wasTimeout === undefined) {
          result.wasTimeout = false;
        }

        writeResponse(ptrResponse, result);
      }

      function shutdown() {
        if (host && typeof host.shutdown === "function") {
          try {
            host.shutdown();
          } catch (err) {
            console.warn("NativeMessageBox: shutdown threw an error.", err);
          }
        }
      }

      return {
        dispatch,
        shutdown
      };
    };
  }

  const managedState = {
    host: null,
    runtimeName: "",
    logCallback: null
  };

  function bindManagedLog() {
    if (managedState.logCallback) {
      return managedState.logCallback;
    }

    if (Module && typeof Module.mono_bind_static_method === "function") {
      try {
        managedState.logCallback = Module.mono_bind_static_method("[NativeMessageBox]NativeMessageBox.Interop.NativeMessageBoxBrowserInterop:DispatchLog");
        return managedState.logCallback;
      } catch (err) {
        console.warn("NativeMessageBox: failed to bind managed log callback.", err);
      }
    }

    return null;
  }

  function getManagedHost(ModuleInstance) {
    if (managedState.host && managedState.host.showMessageBox) {
      return managedState.host;
    }

    if (ModuleInstance.nativeMessageBox && ModuleInstance.nativeMessageBox.showMessageBox) {
      managedState.host = ModuleInstance.nativeMessageBox;
      return managedState.host;
    }

    if (typeof ModuleInstance.nmbManagedHostFactory === "function") {
      managedState.host = ModuleInstance.nmbManagedHostFactory(ModuleInstance);
    } else {
      managedState.host = createDefaultHost(ModuleInstance);
    }

    ModuleInstance.nativeMessageBox = managedState.host;
    return managedState.host;
  }

  function managedLog(message, level = "info") {
    if (typeof managedState.logCallback === "function") {
      try {
        managedState.logCallback(`[${level}] ${String(message)}`);
      } catch (err) {
        console.warn("NativeMessageBox: managed log callback threw.", err);
      }
    } else if (level === "error") {
      console.error(message);
    } else {
      console.log(message);
    }
  }

  function normalizeManagedRequest(request) {
    if (!request || typeof request !== "object") {
      return {
        title: "",
        message: "",
        buttons: [],
        allowEscape: true,
        showSuppressCheckbox: false,
        requiresExplicitAck: false
      };
    }

    const normalized = { ...request };
    if (!Array.isArray(normalized.buttons) || normalized.buttons.length === 0) {
      normalized.buttons = [{ id: 1, label: "OK", isDefault: true, isCancel: false }];
    }

    normalized.message = typeof normalized.message === "string" ? normalized.message : "";
    normalized.title = typeof normalized.title === "string" ? normalized.title : "";
    normalized.allowEscape = normalized.allowEscape !== false;
    normalized.showSuppressCheckbox = normalized.showSuppressCheckbox === true;
    normalized.requiresExplicitAck = normalized.requiresExplicitAck === true;
    normalized.timeoutMilliseconds = Number(normalized.timeoutMilliseconds || 0);
    normalized.timeoutButtonId = Number(normalized.timeoutButtonId || 0);

    if (normalized.input && typeof normalized.input === "object") {
      normalized.input.mode = Number(normalized.input.mode || 0);
      if (normalized.input.mode === InputMode.COMBO) {
        if (!Array.isArray(normalized.input.comboItems)) {
          normalized.input.comboItems = [];
        } else {
          normalized.input.comboItems = normalized.input.comboItems.map((item) =>
            typeof item === "string" ? item : ""
          );
        }
      }
    } else {
      normalized.input = null;
    }

    if (normalized.secondary && typeof normalized.secondary === "object") {
      const secondary = normalized.secondary;
      secondary.informativeText = typeof secondary.informativeText === "string" ? secondary.informativeText : undefined;
      secondary.expandedText = typeof secondary.expandedText === "string" ? secondary.expandedText : undefined;
      secondary.footerText = typeof secondary.footerText === "string" ? secondary.footerText : undefined;
      secondary.helpLink = typeof secondary.helpLink === "string" ? secondary.helpLink : undefined;
      normalized.secondary = secondary;
    } else {
      normalized.secondary = null;
    }

    return normalized;
  }

  if (!globalThis.NativeMessageBoxManaged) {
    globalThis.NativeMessageBoxManaged = {
      initialize(runtimeName) {
        managedState.runtimeName = typeof runtimeName === "string" ? runtimeName : "";
        managedLog(`NativeMessageBox managed host initialized (${managedState.runtimeName})`, "info");
      },
      enableLogging() {
        const bound = bindManagedLog();
        if (!bound) {
          console.warn("NativeMessageBox: managed log callback unavailable.");
        }
      },
      disableLogging() {
        managedState.logCallback = null;
      },
      async showMessageBox(requestJson) {
        let request;
        try {
          request = requestJson ? JSON.parse(requestJson) : {};
        } catch (err) {
          managedLog("NativeMessageBox: failed to parse managed request JSON.", "error");
          managedLog(err, "error");
          return JSON.stringify({
            resultCode: ResultCode.InvalidArgument,
            buttonId: 0,
            checkboxChecked: false,
            wasTimeout: false,
            inputValue: null
          });
        }

        const ModuleInstance = Module;
        const host = getManagedHost(ModuleInstance);
        if (!host || typeof host.showMessageBox !== "function") {
          managedLog("NativeMessageBox: host missing showMessageBox implementation for managed pipeline.", "error");
          return JSON.stringify({
            resultCode: ResultCode.PlatformFailure,
            buttonId: 0,
            checkboxChecked: false,
            wasTimeout: false,
            inputValue: null
          });
        }

        const normalized = normalizeManagedRequest(request);
        try {
          const result = await host.showMessageBox(normalized);
          if (!result || typeof result !== "object") {
            return JSON.stringify({
              resultCode: ResultCode.PlatformFailure,
              buttonId: 0,
              checkboxChecked: false,
              wasTimeout: false,
              inputValue: null
            });
          }

          return JSON.stringify({
            resultCode: typeof result.resultCode === "number" ? result.resultCode : ResultCode.OK,
            buttonId: typeof result.buttonId === "number" ? result.buttonId : 0,
            checkboxChecked: !!result.checkboxChecked,
            wasTimeout: !!result.wasTimeout,
            inputValue: typeof result.inputValue === "string" ? result.inputValue : null
          });
        } catch (err) {
          managedLog("NativeMessageBox: managed host dispatch failed.", "error");
          managedLog(err, "error");
          return JSON.stringify({
            resultCode: ResultCode.PlatformFailure,
            buttonId: 0,
            checkboxChecked: false,
            wasTimeout: false,
            inputValue: null
          });
        }
      },
      shutdown() {
        const ModuleInstance = Module;
        if (ModuleInstance.nativeMessageBox && typeof ModuleInstance.nativeMessageBox.shutdown === "function") {
          try {
            ModuleInstance.nativeMessageBox.shutdown();
          } catch (err) {
            managedLog("NativeMessageBox: managed host shutdown threw.", "error");
            managedLog(err, "error");
          }
        }

        managedState.host = null;
        managedLog("NativeMessageBox managed host shutdown.", "info");
      }
    };
  }
})();
