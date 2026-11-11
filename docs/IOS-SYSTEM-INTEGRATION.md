# VOID iOS System Integration

## Local multilingual model

VOID Local and the Ask VOID App Intent use Qwen3 0.6B through the Core AI runtime. Qwen3 supports 100+ languages, including Arabic. The model is downloaded once on first use (approximately 456 MB for the iPhone bundle), then cached locally for later offline use. There is no provider API key or per-request API fee. First download requires network access.

## Supported iOS entry points

- **VOID Local**: a local chat surface inside the app.
- **Ask VOID**: an App Intent exposed through App Shortcuts for Siri, Shortcuts, Spotlight, and supported system surfaces. Users can assign an App Shortcut to the iPhone Action button on supported devices.
- **VOID Keyboard**: an optional custom keyboard with Improve, Shorten, and Translate actions for explicitly selected text. It uses the lighter Apple system model to avoid loading the larger Qwen engine inside the keyboard process. The Apple system model language support varies; Arabic requests should use VOID Local or Ask VOID.

## Platform limits

iOS does not let an ordinary third-party app replace the system assistant globally, read every other app's screen, or run unrestricted background code. The custom keyboard is available only in text fields that allow third-party keyboards. Secure text fields use the system keyboard, and an app may explicitly reject custom keyboards.

The keyboard receives only the text context exposed by UITextDocumentProxy. VOID's keyboard actions require an explicit text selection and insert the replacement only if the selection has not changed. Keyboard Full Access is disabled; selected text is not sent to a remote server by keyboard actions.

The Core AI model requires iOS 27 and a compatible device. The first request downloads the iPhone Qwen3 bundle and caches it in the app's Application Support directory. Inference after the download runs on-device. A cold model load can take longer than later responses, and App Intent execution budgets must be tested on a real device.

## Build and signing

The keyboard is packaged as PlugIns/VOIDKeyboard.appex with bundle ID net.stupidtech.StupidAgent.keyboard. The containing app's bundle ID and existing App Group are unchanged. The keyboard does not request the App Group entitlement or keyboard Full Access.

A release or device install must include the keyboard extension's provisioning profile and signature. An unsigned IPA is not directly installable; re-signing must preserve the nested keyboard extension bundle and its bundle ID.
