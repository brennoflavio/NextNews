# NextCommon Integration Guide

NextCommon is vendored source. It must not become a runtime dependency between
apps.

## Recommended Layout

```text
AppRepo/
  vendor/
    NextCommon/
      qml/
      js/
      assets/
      docs/
```

## QML Resource Aliases

Add only the files the app uses to `qml/qml.qrc`:

```xml
<file alias="NextCommon/qmldir">../vendor/NextCommon/qml/NextCommon/qmldir</file>
<file alias="NextCommon/VERSION">../vendor/NextCommon/qml/NextCommon/VERSION</file>
<file alias="NextCommon/AboutPage.qml">../vendor/NextCommon/qml/NextCommon/AboutPage.qml</file>
<file alias="NextCommon/AccountPage.qml">../vendor/NextCommon/qml/NextCommon/AccountPage.qml</file>
<file alias="NextCommon/AccountSessionAdapter.qml">../vendor/NextCommon/qml/NextCommon/AccountSessionAdapter.qml</file>
<file alias="NextCommon/AvatarButton.qml">../vendor/NextCommon/qml/NextCommon/AvatarButton.qml</file>
<file alias="NextCommon/DrawerShell.qml">../vendor/NextCommon/qml/NextCommon/DrawerShell.qml</file>
<file alias="NextCommon/MainTopBar.qml">../vendor/NextCommon/qml/NextCommon/MainTopBar.qml</file>
```

Then import them:

```qml
import "qrc:/NextCommon" as NextCommon
```

## Full Page Wrappers

Use thin app-local wrappers for shared full-page components. The wrapper should
provide app identity, service ids, and app-specific callbacks while leaving the
shared behavior in NextCommon.

Example:

```qml
import QtQuick 2.7
import "qrc:/NextCommon" as NextCommon

NextCommon.AccountPage {
    appName: appController.appName
    logPrefix: "NextDeck"
    appApplicationId: "nextdeck.cloudsite_nextdeck"
    nextcloudServiceId: "nextdeck.cloudsite_nextdeck_nextcloud"
    owncloudServiceId: "nextdeck.cloudsite_nextdeck_owncloud"

    onAccountAuthorized: {
        appController.accountChanged(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl)
    }
}
```

## Online Accounts Invariant

Next Apps must only use Nextcloud or ownCloud accounts that already exist in
Ubuntu Touch System Settings > Accounts.

The normal account-selection and account-switch flow must never open a
provider login/setup page. In practice this means:

- do not import `Lomiri.OnlineAccounts.Client` in shared account UI
- do not instantiate `Setup`
- do not call `Setup.exec()` or `accountSetup.exec()`
- do not add in-app username/password/app-password login
- do not store or log secrets
- do not call `selectedService.updateServiceEnabled(true)` as production flow

Allowed behavior:

- list existing `nextcloud` and `owncloud` Online Accounts services
- select the app-specific service id for the current app
- authenticate with `AccountService.authenticate({})`
- keep returned credentials only in memory for the current app session
- if the service is not approved, explain that the user must allow the app in
  Ubuntu Touch System Settings > Accounts
- retry verification after the user returns to the app

Contract tests must fail if shared account code reintroduces
`Lomiri.OnlineAccounts.Client`, `Setup {`, `accountSetup.exec()`, or
`settings://system/online-accounts`.

## UTControls Boundary

Low-level reusable controls are intentionally not part of NextCommon. Use the
separate `UTControls` module for:

- app buttons
- confirm dialogs
- empty states
- section/status rows
- calendar and time pickers
- reorderable list controls

This keeps NextCommon focused on NextApps suite behavior while UTControls stays
domain-neutral and reusable outside the suite.

For reorder behavior, follow the `UTControls` integration guide. The app must
still own persistence/cache/sync/server writes.

## Rules

- Pin each app to the exact NextCommon commit/version it has tested.
- Different apps in the NextApps suite may intentionally use different
  NextCommon versions at the same time.
- Update shared behavior in the NextCommon repository first, bump the version
  when appropriate, then update the consuming app's submodule pointer.
- Do not edit vendored NextCommon files inside an app as a local copy.
- Do not put test credentials in NextCommon.
- Do not put private handoff files in NextCommon.
- Do not add AppArmor policy just because NextCommon is used.
- Do not add a shared system package.
- Keep app-specific strings and app-specific behavior in the app unless the
  component is truly reusable.
