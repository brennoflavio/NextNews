# NextCommon Versioning

NextCommon is a source-level module. Apps vendor it as a git submodule and
package the selected source version inside their own click package.

## Rules

- Each app pins the exact NextCommon commit/version it has been tested with.
- Apps in the NextApps suite may intentionally use different NextCommon versions
  at the same time.
- Updating NextCommon in one app does not automatically update any other app.
- Shared-module updates should be tested in the app that consumes the new
  version before release.
- Do not edit vendored NextCommon files inside an app. Make changes in the
  NextCommon repository, bump the version when appropriate, then update the
  consuming app's submodule pointer.

## Version History

### 0.2.1

- Added optional `contributorsText` support to `AboutPage`.
- Added a dedicated `Disclaimer` section to `AboutPage`.

### 0.2.0

- Split low-level generic controls out to UTControls.
- Kept NextCommon focused on NextApps suite shells and workflows.
- Added shared account, language, drawer, top-bar, settings, about, avatar, and
  sync-badge components.
