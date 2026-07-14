# NextCommon

Shared source-level components for the NextApps for Ubuntu Touch app family.

NextCommon is not a runtime shared library and is not installed as a system
component. Each app should include this repository as a git submodule, usually
under `vendor/NextCommon/`, and package those source files inside its own Click
package.

## Scope

Current stable scope:

- Shared account, language, settings, drawer, top-bar, and about-page shells
- Shared avatar and sync-badge UI used by the app shells
- Small JavaScript helper modules
- Shared design and integration documentation
- Contract tests that protect the public source layout

Generic controls such as buttons, dialogs, empty states, section headers,
date/time pickers, and reorderable list controls belong in `UTControls`, not in
NextCommon. Apps should vendor both modules when they need both app-suite
shells and low-level controls.

Out of scope for the first version:

- Search header
- App-specific list/card delegates
- Sync state models
- Runtime dependencies between apps
- Secrets, test account data, private handoff files, or release-only notes

## Integration

Add this repository as a source-level submodule in an app repository:

```bash
git submodule add ../NextCommon vendor/NextCommon
git submodule update --init --recursive
```

Then include the used QML/JS files in the app's `qml.qrc` with stable aliases,
for example:

```xml
<file alias="NextCommon/AvatarButton.qml">../vendor/NextCommon/qml/NextCommon/AvatarButton.qml</file>
<file alias="NextCommon/qmldir">../vendor/NextCommon/qml/NextCommon/qmldir</file>
<file alias="NextCommon/VERSION">../vendor/NextCommon/qml/NextCommon/VERSION</file>
```

Import from QML:

```qml
import "qrc:/NextCommon" as NextCommon
```

Each app pins its submodule to the exact tagged NextCommon release it has
tested (e.g. `v0.3.0`), not an arbitrary commit. Apps in the NextApps suite
may intentionally use different NextCommon versions until each app is
upgraded and verified. See `docs/versioning.md`.

## License

MIT License. Copyright (c) 2026 Etherghost.
