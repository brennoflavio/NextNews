# NextNews

NextNews is a native Ubuntu Touch client for Nextcloud News.

This project follows the same Ubuntu Touch development approach as NextNotes, NextTasks, and the rest of the Nextcloud app suite.

NextNews is not affiliated with, endorsed by, or sponsored by Nextcloud GmbH or the Nextcloud project.

## Features

Current V1 scaffold:

- Use an existing Nextcloud or ownCloud account from Ubuntu Touch Online Accounts.
- Authorize the app with the shared OS-account-only Online Accounts flow used by the Nextcloud app suite.
- Show the selected account avatar from the Nextcloud account when available.
- Use runtime-only Online Accounts credentials.
- Read the server address from the selected Ubuntu Touch account, with an editable server-address field if the system account does not expose the correct host.
- Connect to the Nextcloud News API at `/index.php/apps/news/api/v1-2/`.
- Load folders, feeds, and article items.
- Add feeds to the selected Nextcloud News account.
- Create folders, rename folders, move feeds to folders, rename feeds, and delete feeds.
- Create a folder directly from the Add feed dialog and wait for the server folder id before posting the feed.
- Delete folders; feeds inside the folder are deleted first, matching the established Nextcloud News workflow.
- Keep folder/feed selector models in sync with the cached/server folder list.
- Show cached articles first, then refresh from the server.
- Group articles by date sections such as Today, Yesterday, and calendar date.
- Read cached articles offline.
- Retry failed feed/folder rename, move, and delete operations on the next successful sync.
- Mark articles read or unread.
- Swipe article rows right to star/unstar and left to toggle read/unread state.
- Star or unstar articles when the API has the required `feedId` and `guidHash`.
- Mark all unread articles in the current view as read with the drag-up floating action button, then upload that read state as a single batch when online.
- Preserve pending local read/star state when upload fails.
- Attempt to upload pending local article state when the app is deactivated.
- Review pending local article/subscription changes from the sync status icon and choose whether to keep, retry, or discard them. Pending sync uses a filled status dot; warning symbols are reserved for real failures.
- Refresh while the app is active, with settings for active sync, startup sync, and interval.
- Search cached titles, authors, and cached article text.
- Choose title/content/both search scope.
- Show unread counts in the navigation drawer.
- Separate views, folders, and feeds in the navigation drawer.
- Configure oldest/newest sort order, open articles directly in the browser, and mark articles read while scrolling.
- Configure individual feeds to open directly in the browser.
- Open article links from the article detail page.
- Share article title and link to other Ubuntu Touch apps through Content Hub.
- Use a local SQLite cache through Qt LocalStorage.
- Show an About page with version, license, copyright, contributors, and Nextcloud affiliation disclaimer. Longer product/license/disclaimer text intentionally remains in English across translations.

## Not Included

The first version intentionally does not implement:

- In-app username/password/app-password login
- Always-running background service
- Background push notifications
- Full-text web archive download
- Podcast playback
- Image caching
- Complex merge-style conflict UI
- Rich article rendering

## Authentication

NextNews always uses Ubuntu Touch Online Accounts only.

Add a Nextcloud or ownCloud account in Ubuntu Touch System Settings > Accounts, then select that account inside NextNews. If Ubuntu Touch has not yet allowed NextNews to use the account, the account page opens a guided prompt to System Settings > Accounts, keeps the account selected, and verifies access automatically when you return. Credentials are taken from the selected system account. The server address is read from the account when available and can be corrected in the account page if Ubuntu Touch does not expose the correct host. Credentials are requested from Online Accounts at runtime and are not stored by NextNews. After successful runtime authentication, credentials may be kept only in process memory for the current app session.

## Languages

Current language choices:

- Follow system language
- English
- Swedish
- Catalan
- German
- French
- Dutch
- Danish
- Norwegian Bokmal
- Spanish
- Finnish

Swedish and Catalan have initial translations for the current UI. German, French, Dutch, Danish, Norwegian Bokmal, Spanish, and Finnish currently use partial AI-assisted starter translations and need review by fluent speakers. Untranslated strings fall back to the built-in English source text.

Translations are gettext `.po` files under `po/`. Improvements are welcome by editing the relevant language file or adding a new `.po` catalog based on `po/nextnews.cloudsite.pot`.

## Architecture

NextNews is a Clickable QML/C++ Ubuntu Touch application.

Important areas:

- `qml/pages/`: Ubuntu Touch UI pages.
- `qml/backend/AccountSessionAdapter.qml`: thin NextNews wrapper around the shared Online Accounts runtime authentication adapter.
- `vendor/NextCommon/`: vendored versioned shared suite module used for account/session UI and helpers. This is source-vendored, not a git submodule.
- `qml/UTControls/`: vendored versioned Ubuntu Touch controls module.
- `qml/backend/NewsApiClient.qml`: Nextcloud News API requests.
- `qml/backend/NewsApiCore.js`: URL, payload, and JSON parsing helpers.
- `qml/backend/NewsCache.qml`: local SQLite cache.
- `qml/backend/NewsController.qml`: cached-first loading, filtering, sync orchestration, and UI-facing state.
- `qml/backend/SyncPlanner.js`: pending local state upload planning.
- `po/`: gettext translation catalogs.
- `tests/`: local contract and regression tests.
- `tests_live/`: opt-in live Nextcloud News API tests.

The backend boundary is intentionally similar to NextNotes so future improvements can reuse the same testing and synchronization patterns.

## Build

Install Clickable, then build from the repository root:

```bash
~/.local/bin/clickable build --arch amd64
~/.local/bin/clickable build --arch arm64
```

Successful builds produce click packages under:

```text
build/x86_64-linux-gnu/app/
build/aarch64-linux-gnu/app/
```

## Run

Desktop mode:

```bash
~/.local/bin/clickable desktop --arch amd64
```

Larger desktop debug window:

```bash
~/.local/bin/clickable script desktop-large
```

Dark desktop debug window:

```bash
~/.local/bin/clickable script desktop-dark
```

Desktop mode can also use the dedicated live-test account from `.env.test.local`
for faster debugging without Ubuntu Touch Online Accounts:

```bash
cp .env.test.local.example .env.test.local
# edit .env.test.local with a dedicated test account
~/.local/bin/clickable script desktop-test
~/.local/bin/clickable script desktop-test-dark
```

This path is only enabled for desktop debugging when `NEXTNEWS_DESKTOP_TEST_AUTH=1`
is set by the script. Ubuntu Touch builds continue to use Online Accounts only.

Install on a connected Ubuntu Touch device:

```bash
~/.local/bin/clickable install --arch arm64 --skip-uninstall
```

Use `--skip-uninstall` for normal development installs when the version number has increased. Do a full uninstall/reinstall only when intentionally testing a clean install or changing AppArmor permissions, account hooks, or package identity.

This version changes AppArmor permissions for external link/share handling, so device
testing should use a clean reinstall once before returning to normal `--skip-uninstall`
development installs.

## Test

Run the local regression suite:

```bash
~/.local/bin/clickable script test
```

Optional live Nextcloud News API tests are available for a dedicated test account. They create, rename, move, and delete test folders/feeds with a `NextNewsLiveTest-` prefix and should never be run against a personal account:

```bash
cp .env.test.local.example .env.test.local
# edit .env.test.local with a dedicated test account
~/.local/bin/clickable script test-live
```

Never use a personal account for live tests. `.env.test.local` is ignored by git. The live suite also tests read/unread and star/unstar when the configured test feed returns articles quickly enough.

## Deployment

NextNews is intended for OpenStore distribution as a click package.

Release notes are maintained in [CHANGELOG.md](CHANGELOG.md).

## Dependencies

- Ubuntu Touch
- Clickable
- Qt/QML with Lomiri Components
- Qt LocalStorage
- Ubuntu Touch Online Accounts
- Nextcloud News server app

## Permissions

The AppArmor profile uses:

- `networking`: connect to the configured Nextcloud server.
- `accounts`: access Ubuntu Touch Online Accounts after user authorization.
- `content_exchange`: open article URLs through Ubuntu Touch.
- `content_exchange_source`: share article links through Ubuntu Touch.

NextNews does not request unconfined mode.

## Current Status

NextNews builds as `nextnews.cloudsite`, includes a News-specific API/cache/controller boundary, passes local contract tests, and uses the shared vendored NextCommon account/session modules plus vendored UTControls. The account flow is intentionally OS-account-only and does not expose manual login. Account switching clears stale in-memory credentials and ignores delayed auth/API responses from the previous account. Feed creation, folder creation, feed/folder rename, feed move/delete, folder delete, active sync settings, unread navigation counts, search scope, sort settings, direct browser opening, Content Hub article sharing, article-detail link handling, and Catalan language support are implemented. The experimental mark-read-while-scrolling option is disabled and hidden because device testing showed unreliable behavior; it is deferred to a future release.

## License

NextNews is licensed under the MIT License.

Copyright (c) 2026 Etherghost. See [LICENSE](LICENSE).
