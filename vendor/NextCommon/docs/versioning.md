# NextCommon Versioning

NextCommon is a source-level module. Apps vendor it as a git submodule and
package the selected source version inside their own click package.

## Rules

- Each app pins its submodule to a **tagged release** (e.g. `v0.3.0`), not an
  arbitrary commit. Submodules always record a commit SHA internally, but that
  SHA must correspond to a tag - the tag name, not the hash, is what apps and
  commit messages refer to. This keeps a bare `git log` on the pinned commit
  meaningful instead of an opaque hash, and makes it possible to tell at a
  glance whether an update is a patch, a feature, or a breaking change.
- Apps in the NextApps suite may intentionally use different NextCommon
  versions at the same time.
- Updating NextCommon in one app does not automatically update any other app.
- Shared-module updates should be tested in the app that consumes the new
  version before release.
- Do not edit vendored NextCommon files inside an app. Make changes in the
  NextCommon repository, bump `qml/NextCommon/VERSION` and this changelog, tag
  the release, then update the consuming app's submodule pointer to that tag.

## Version History

### 0.3.1

- Migrated `AccountSessionAdapter` from `Ubuntu.OnlineAccounts 0.1` to
  `Lomiri.OnlineAccounts 2.0`. This is the credential-fetching path used for
  every actual sync/API call, separate from `AccountPage`'s account picker
  (migrated in 0.3.0). Removes the last native-crash-prone code path: an
  account whose approval is revoked while already selected and syncing now
  fails cleanly instead of risking the same native crash class fixed in
  `AccountPage` for 0.3.0. Also drops the old adapter's `includeDisabled`
  toggle/retry dance, which doesn't apply to the new API (it never returns
  unapproved accounts in the first place).

### 0.3.0

- Migrated `AccountPage` from `Ubuntu.OnlineAccounts 0.1` to
  `Lomiri.OnlineAccounts 2.0`, fixing a native crash when authenticating an
  account not yet approved for the app in System Settings.
- Added live refresh of the account list/grants when the page or app becomes
  active again, and a persistent "Add another account" link.
- Fixed stale Online Accounts state being reused before a fresh prompt.

### 0.2.1

- Added optional `contributorsText` support to `AboutPage`.
- Added a dedicated `Disclaimer` section to `AboutPage`.

### 0.2.0

- Split low-level generic controls out to UTControls.
- Kept NextCommon focused on NextApps suite shells and workflows.
- Added shared account, language, drawer, top-bar, settings, about, avatar, and
  sync-badge components.
