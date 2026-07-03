# NextApps Design Guide

NextApps for Ubuntu Touch should feel like one product family while still using
native Ubuntu Touch/Lomiri controls. NextCommon is a source-level shared library:
apps vendor it as a submodule and package the QML/JS with their own click.

## Principles

- Keep screens practical, quiet, and touch-friendly.
- Prefer compact native controls over decorative UI.
- Use the shared top bar, drawer, account, language, settings, status, and about
  patterns across apps.
- Keep app-specific workflows and domain logic in each app, not in NextCommon.
- Keep components explicit and dependency-light.
- Never add an in-app username/password/app-password login flow. NextApps use
  Ubuntu Touch Online Accounts only.

## Shared Shell

- `MainTopBar`: hamburger action, search field, filter action, sync/status action,
  and avatar/account action.
- `DrawerShell`: shared hamburger drawer frame with app title, scrollable app
  content, and bottom navigation entries.
- `DrawerNavItem`: drawer list item with optional count/status text.
- `SettingsShell`: scrollable settings page shell.
- `SettingsCard`: reusable framed settings block.

## Shared Account And Language

- `AccountPage`: Ubuntu Touch Online Accounts account selection and verification
  UI. It must only use existing OS accounts and must not open provider login or
  setup pages.
- `AccountSessionAdapter`: runtime credential adapter for
  `AccountService.authenticate({})`. Secrets are kept in memory only.
- `LanguagePage`: shared manual/system language selection page.

## Shared Buttons And Status

- `AppButton`: default text action button. Neutral buttons have transparent
  background and no border; destructive actions use red text. Use this for most
  popup and page actions.
- `FlatActionButton` and `FlatStepButton`: small flat action controls for compact
  tool/picker UI.
- `AvatarButton`: circular account/avatar action.
- `StatusRow`: compact status text row.
- `SyncBadge`: small visual badge for simple status labels.
- `EmptyState`: small empty/loading/error text block.
- `ConfirmDialog`: simple confirmation/destructive dialog body.
- `SectionHeader`: section label used in drawers and forms.

## Shared Pickers And Lists

- `CalendarDatePicker`: shared date picker dialog.
- `TimePicker`: shared time picker dialog.
- `ReorderableListView`: domain-neutral reorderable list. It uses an internal
  visual model, placeholder row, drag overlay, auto-scroll, and pull-to-refresh.
  Apps own persistence and sync through `moveRequested(fromIndex, toIndex)`.

## App-Specific Responsibilities

- API clients, cache models, sync queues, conflict resolution, and domain-specific
  list/card delegates belong in each app.
- Content Hub import/export behavior belongs in each app unless a later shared
  helper is proven useful across multiple apps.
- Card/list row visuals may share style guidance, but should only move to
  NextCommon after at least two apps use the same behavior.

## Visual Style

- Drawer bottom navigation uses flat, unframed actions.
- General action buttons should be neutral/flat by default.
- Destructive actions should be clearly red but still use the same shared button
  component.
- Use rounded corners sparingly; cards and settings blocks should stay modest.
- Keep text readable in both Lomiri light and dark themes.
