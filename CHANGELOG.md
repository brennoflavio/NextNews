# Changelog

## Unreleased

## 0.4.0 - 2026-07-14

Translation and reliability release.

- Updated `vendor/NextCommon` and `qml/UTControls` to their current shared
  content, picking up the Lomiri.OnlineAccounts 2.0 migration (avoids a
  native crash risk when an account is not yet approved or has its approval
  revoked mid-session) and other suite-wide fixes.
- Fixed `main.cpp`'s `localeForLanguageCode()` only mapping some languages -
  Italian, Polish, Russian, and Ukrainian were missing, and would have
  silently fallen back to the system locale if selected.
- Added a request timeout to all News API calls so a stalled connection can
  no longer wedge the app until restart.
- Removed 61 leftover diagnostic `console.log` calls from release code, and
  added a contract test to catch any that come back.
- Added Italian, Polish, Russian, and Ukrainian as language choices, and
  completed translation coverage for all 13 supported languages - most
  non-English, non-Swedish languages were only partially translated (as low
  as ~15% of strings), and a review pass also fixed a number of existing
  translations that had incorrect content or missing placeholders.
- Fixed two contract tests left over from an earlier account-module version
  bump that still checked internal details of an already-replaced Online
  Accounts API.
- Dropped "but simple" from the tagline.

## 0.3.0 - 2026-07-03

Polish and platform-alignment release.

- Ports account selection and runtime authentication to the shared versioned NextApps module used by the app suite.
- Adds the versioned Ubuntu Touch controls module used by newer NextApps UI.
- Improves Settings wording and layout consistency, including the swipe-direction option.
- Improves article detail with feed identity, author/date metadata, better link handling, and fixed HTML entity decoding.
- Adds Catalan as a visible language option.

## 0.2.0 - 2026-06-26

- Added Ubuntu Touch Content Hub article sharing.
- Article title and link can now be shared to other Ubuntu Touch apps.
- Removed the old email-only article sharing action.

## 0.1.8 - 2026-06-23

- Polish release.
- Updates the app icon and banner artwork.
- Introduces a cleaner, more modern navigation drawer and account page design.
- Removes the drawer Refresh action; pull-to-refresh remains available in the article list.

## 0.1.7 - 2026-06-19

- Fixed account setup for accounts that are not yet approved for NextNews in Ubuntu Touch Online Accounts. If authorization fails, the account page now shows the system accounts dialog and an Open system accounts button so the user can grant access.

## 0.1.6 - 2026-06-19

- Improved the account setup prompt so a selected account stays selected and is verified automatically after the user returns from Ubuntu Touch account settings.
- Hardened account switching so stale Online Accounts callbacks and delayed News API responses from a previous account are ignored after selecting another account.
- Restyled the Settings page into compact grouped cards matching NextNotes.
- Added a swipe-direction setting with Ubuntu Touch style as default and Android-compatible behavior as an option.
- Disabled the active sync interval controls when "Sync while app is active" is turned off.

## 0.1.5 - 2026-06-17

- Replaced the height-changing article-list status strip with a compact top-bar sync status icon.
- Added a pending-changes review page for local article read/star and subscription changes, with actions to keep local changes, retry sync, or discard local pending changes and refresh from the server.
- Changed pending sync to use a filled status dot instead of a warning icon.
- Uploads "mark all read" changes immediately as one batch request, while ordinary read/star changes still use the short 1.2 second debounce.
- Attempts to upload pending local article state when the app is deactivated.

## 0.1.4 - 2026-06-17

- Aligned the account page with the shared Nextcloud suite flow: clickable account rows, guided Ubuntu Touch account-setting approval, automatic verification after account selection, and immediate controller refresh after changing account.
- Added the Content Hub AppArmor permissions required by NextNews external link and email sharing actions, while keeping Online Accounts and networking unchanged.
- Removed normal account-page diagnostic output and made account switching clear stale in-memory credentials before verifying the newly selected account.
- Fixed an account-list layout warning in Lomiri `ListItem` during account switching.
- Fixed the Swedish account authorization success text after a translation merge issue.

## 0.1.3 - 2026-06-14

- Improved article list cards with a cleaner NextNotes-inspired layout, better spacing, and a subtler read/unread visual treatment.
- Added feed identity to article cards, including feed favicon or fallback initial, feed name, and a visual favorite star for starred articles.
- Fixed short article titles so they align to the top of the card instead of appearing on the second line.
- Added pull-to-refresh status text in the article list: pull, release, and refreshing states now match the NextNotes behavior.
- Added visible language choices matching NextNotes: English, Swedish, German, French, Dutch, Danish, Norwegian Bokmal, Spanish, and Finnish.
- Added partial AI-assisted starter translation catalogs for German, French, Dutch, Danish, Norwegian Bokmal, Spanish, and Finnish. Untranslated strings fall back to English.
- Added dark desktop debug launch scripts for development and translation testing.

## 0.1.2 - 2026-06-13

- Fixed Online Accounts authorization so selecting an existing Ubuntu Touch account does not open the provider login page.

## 0.1.1 - 2026-06-13

- Fixed article swipe actions: swipe right now toggles star/favorite, and swipe left toggles read/unread.
- Fixed unreadable navigation drawer row text in light mode for Views, Folders, and Feeds.

## 0.1.0 - 2026-06-13

- Initial OpenStore release.
- Supports Ubuntu Touch Online Accounts for Nextcloud/ownCloud authentication.
- Lists Nextcloud News folders, feeds, and articles.
- Supports cached/offline reading of previously loaded articles.
- Supports adding, renaming, moving, and deleting feeds.
- Supports creating, renaming, and deleting folders.
- Supports marking articles read/unread and starring/unstarring articles.
- Supports pull-to-refresh, active sync while the app is open, and pending read/star changes after network failures.
- Includes article search, settings, Swedish translation, About page, and OpenStore-ready app identity.
