# VOID iOS System Integration

## Goal

VOID can be used beyond its own chat screen through supported iOS extension points. The first implementation uses Apple's on-device Foundation Models framework, so prompts handled by the local mode do not require a provider API key or per-request API billing.

## Included entry points

- **VOID Local**: a local chat surface inside the app.
- **VOID Keyboard**: an optional custom keyboard with Improve, Shorten, and Translate actions. It only processes text the user explicitly selects. Keyboard open access is disabled; it does not request network access or use a shared App Group container.
- **Ask VOID**: an App Intent exposed through App Shortcuts for Siri, Shortcuts, Spotlight, and supported system surfaces. A user can also assign an App Shortcut to the iPhone Action button on supported devices.

## Platform limits

iOS does not let an ordinary third-party app replace the system assistant globally, read every other app's screen, or run unrestricted background code. The custom keyboard is available only in text fields that allow third-party keyboards. Secure text fields use the system keyboard, and an app may explicitly reject custom keyboards.

The keyboard receives only the text context exposed by UITextDocumentProxy. VOID's AI actions require an explicit text selection and insert the replacement only if the selection has not changed. The keyboard uses Apple's local model and does not send selected text to a remote server.

The Foundation Models model must be available on the user's device and region and may need the operating system to finish preparing its model resources. If it is unavailable, the local chat, keyboard, and App Intent show an error instead of silently falling back to a paid API.

## Build and signing

The keyboard is packaged as PlugIns/VOIDKeyboard.appex with bundle ID net.stupidtech.StupidAgent.keyboard. The containing app's bundle ID and existing App Group are unchanged. The keyboard does not request the App Group entitlement or keyboard Full Access.

A release or device install must include the keyboard extension's provisioning profile and signature. An unsigned IPA is not directly installable; re-signing must preserve the nested keyboard extension bundle and its bundle ID.
