import json
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


def read_text(path):
    return (ROOT / path).read_text(encoding="utf-8")


class ProjectIdentityTests(unittest.TestCase):
    def test_manifest_identity_and_hooks_are_nextnews(self):
        manifest = json.loads(read_text("manifest.json.in"))

        self.assertEqual(manifest["name"], "nextnews.cloudsite")
        self.assertEqual(manifest["title"], "NextNews")
        self.assertIn("nextnews", manifest["hooks"])
        self.assertEqual(manifest["hooks"]["nextnews"]["accounts"], "nextnews.accounts")
        self.assertEqual(manifest["hooks"]["nextnews"]["apparmor"], "nextnews.apparmor")
        self.assertEqual(manifest["hooks"]["nextnews"]["content-hub"], "nextnews-contenthub.json")
        self.assertEqual(manifest["hooks"]["nextnews"]["desktop"], "nextnews.desktop")

    def test_online_accounts_service_ids_are_current(self):
        page = read_text("qml/pages/AccountSelectionPage.qml")
        common_page = read_text("vendor/NextCommon/qml/NextCommon/AccountPage.qml")

        self.assertIn('import "qrc:/NextCommon" as NextCommon', page)
        self.assertIn("NextCommon.AccountPage", page)
        self.assertIn('appName: "NextNews"', page)
        self.assertIn('logPrefix: "NextNews"', page)
        self.assertIn("nextnews.cloudsite_nextnews", page)
        self.assertIn("nextnews.cloudsite_nextnews_nextcloud", page)
        self.assertIn("nextnews.cloudsite_nextnews_owncloud", page)
        self.assertIn("newsController.applyAccountSelection(", page)

        self.assertIn("findPreferredAppService", common_page)
        self.assertIn("openSystemAccountsDialog", common_page)
        self.assertIn('Qt.openUrlExternally("settings:///system/online-accounts")', common_page)
        self.assertIn("function systemAccountsDialogText()", common_page)
        self.assertIn("function retryAfterSystemApproval()", common_page)
        self.assertIn("waitingForSystemApproval", common_page)
        self.assertIn("selectedHasServiceHandle", common_page)
        self.assertIn("if (!selectedEnabled && !selectedHasServiceHandle)", common_page)
        self.assertIn("if (selectedEnabled || selectedHasServiceHandle)", common_page)
        self.assertIn("page.waitingForSystemApproval = true", common_page)
        self.assertIn("PopupUtils.open(openSystemAccountsDialog)", common_page)
        self.assertIn("visible: page.waitingForSystemApproval", common_page)
        self.assertIn("verify it automatically", common_page)
        self.assertIn("clearSelectedAccount()", common_page)
        self.assertIn("authorizationRunning", common_page)
        self.assertIn("if (page.authorizationRunning)", common_page)
        self.assertIn("page.selectAccount(", common_page)
        self.assertIn("function restoreSelectedAccountFromSettings()", common_page)
        self.assertIn("Open Ubuntu Touch System Settings", common_page)
        self.assertNotIn("select it again", common_page)
        self.assertNotIn("selectedService.updateServiceEnabled(true)", common_page)
        self.assertNotIn('text: row.isSelected ? i18n.tr("Selected") : i18n.tr("Use")', common_page)
        for forbidden in [
            "Lomiri.OnlineAccounts.Client",
            "\n    Setup {",
            "accountSetup.exec()",
            "Discovered services:",
            "Diagnostics",
            "app password",
            "manual login",
        ]:
            self.assertNotIn(forbidden, page)
            self.assertNotIn(forbidden, common_page)
        self.assertNotIn("nextnotes", page.lower())

        session = read_text("qml/backend/AccountSessionAdapter.qml")
        common_session = read_text("vendor/NextCommon/qml/NextCommon/AccountSessionAdapter.qml")
        controller = read_text("qml/backend/NewsController.qml")
        self.assertIn('import "qrc:/NextCommon" as NextCommon', session)
        self.assertIn("NextCommon.AccountSessionAdapter", session)
        self.assertIn('logPrefix: "NextNews"', session)
        self.assertIn("AccountServiceModel", common_session)
        self.assertIn("var accountChanged = currentAccountId !== accountId", common_session)
        self.assertIn("cachedSecret = \"\"", common_session)
        self.assertIn("pendingCallback = null", common_session)
        self.assertIn("accountSettings.serviceId.length > 0", controller)

    def test_apparmor_is_minimal(self):
        apparmor = json.loads(read_text("nextnews.apparmor"))
        content_hub = json.loads(read_text("nextnews-contenthub.json"))

        self.assertEqual(
            sorted(apparmor["policy_groups"]),
            ["accounts", "content_exchange", "content_exchange_source", "networking"],
        )
        self.assertNotIn("unconfined", json.dumps(apparmor).lower())
        self.assertIn("source", content_hub)
        self.assertNotIn("share", content_hub)
        self.assertNotIn("destination", content_hub)

    def test_qml_resources_include_news_runtime_files(self):
        qrc = read_text("qml/qml.qrc")

        for filename in [
            "pages/NewsListPage.qml",
            "pages/ArticleDetailPage.qml",
            "pages/AboutPage.qml",
            "backend/ArticleShareExportPage.qml",
            "backend/ArticleShareExportPageUbuntu.qml",
            "backend/NewsCache.qml",
            "backend/NewsApiClient.qml",
            "backend/NewsApiCore.js",
            "backend/NewsController.qml",
            "backend/SyncPlanner.js",
            'alias="NextCommon/qmldir"',
            'alias="NextCommon/VERSION"',
            'alias="NextCommon/AccountPage.qml"',
            'alias="NextCommon/AccountSessionAdapter.qml"',
            'alias="NextCommon/MainTopBar.qml"',
            'alias="NextCommon/SettingsShell.qml"',
            'alias="NextCommon/UrlHelpers.js"',
            "UTControls/qmldir",
            "UTControls/VERSION",
            "UTControls/AppButton.qml",
            "UTControls/ConfirmDialog.qml",
            "UTControls/TreeReorderableListView.qml",
        ]:
            self.assertIn(filename, qrc)

    def test_vendored_modules_are_source_versioned_not_git_submodules(self):
        qrc = read_text("qml/qml.qrc")
        main = read_text("main.cpp")
        cmake = read_text("CMakeLists.txt")

        self.assertEqual(read_text("vendor/NextCommon/qml/NextCommon/VERSION").strip(), "0.2.1")
        self.assertEqual(read_text("qml/UTControls/VERSION").strip(), "0.2.4")
        self.assertFalse((ROOT / "vendor/NextCommon/.git").exists())
        self.assertFalse((ROOT / ".gitmodules").exists())
        self.assertIn('view.engine()->addImportPath(QStringLiteral("qrc:/"))', main)
        self.assertIn("vendor/NextCommon/qml/NextCommon/*.qml", cmake)
        self.assertIn("vendor/NextCommon/js/*.js", cmake)
        self.assertIn('alias="NextCommon/qmldir"', qrc)

    def test_desktop_test_auth_is_opt_in_and_env_backed(self):
        main = read_text("main.cpp")
        session = read_text("qml/backend/AccountSessionAdapter.qml")
        controller = read_text("qml/backend/NewsController.qml")
        clickable = read_text("clickable.yaml")
        desktop_script = read_text("scripts/desktop-test.sh")
        dark_script = read_text("scripts/desktop-dark.sh")
        main_qml = read_text("qml/Main.qml")

        for snippet in [
            "NEXTNEWS_DESKTOP_TEST_AUTH",
            "NEXTNEWS_TEST_SERVER",
            "NEXTNEWS_TEST_USERNAME",
            "NEXTNEWS_TEST_APP_PASSWORD",
            "desktopTestAuthEnabled",
            "readDesktopTestEnvFile",
            ".clickable/nextnews-desktop-env.local",
        ]:
            self.assertIn(snippet, main)

        for snippet in [
            "envTestAuthEnabled",
            "desktop-test-env",
            "envTestSecret",
        ]:
            self.assertIn(snippet, session + read_text("vendor/NextCommon/qml/NextCommon/AccountSessionAdapter.qml"))

        self.assertIn("accountSession.envTestAuthEnabled", controller)
        self.assertIn("accountSettings.serverUrl = serverUrl", controller)
        self.assertIn('String(serviceId || "") === "desktop-test-env"', controller)
        self.assertIn("desktop-test: bash scripts/desktop-test.sh", clickable)
        self.assertIn("desktop-dark: bash scripts/desktop-dark.sh", clickable)
        self.assertIn("desktop-test-dark: bash scripts/desktop-test.sh --dark", clickable)
        self.assertIn("env_vars:", desktop_script)
        self.assertIn("NEXTNEWS_DESKTOP_TEST_AUTH", desktop_script)
        self.assertIn("NEXTNEWS_DESKTOP_DARK_MODE", desktop_script)
        self.assertIn("NEXTNEWS_DESKTOP_DARK_MODE", dark_script)
        self.assertIn("desktopDarkMode", main)
        self.assertIn("desktopDarkMode", main_qml)
        self.assertIn("SuruDark", main_qml)
        self.assertIn("mktemp .clickable/nextnews-desktop-test", desktop_script)
        self.assertIn("nextnews-desktop-env.local", desktop_script)

    def test_translation_structure_matches_visible_language_choices(self):
        main = read_text("main.cpp")
        language_page = read_text("qml/pages/LanguageSelectionPage.qml")
        readme = read_text("README.md")

        for language_code in ["sv", "ca", "de", "fr", "nl", "da", "nb", "es", "fi"]:
            self.assertIn(f'"{language_code}"', language_page)
            self.assertIn(f'QStringLiteral("{language_code}")', main)
            self.assertTrue((ROOT / "po" / f"{language_code}.po").exists())

        for snippet in [
            "AI-assisted translation",
            "Some translations are AI-assisted and not fully reviewed",
            "Translations are gettext `.po` files under `po/`",
            "Catalan",
        ]:
            self.assertIn(snippet, language_page + readme)

    def test_swedish_account_success_translation_is_not_diagnostics_text(self):
        sv = read_text("po/sv.po")

        self.assertIn("Auktorisering lyckades för %1.", sv)
        self.assertNotIn("enabled=%6Auktorisering lyckades", sv)


class NewsApiContractTests(unittest.TestCase):
    def test_news_api_endpoints_are_v1_2(self):
        core = read_text("qml/backend/NewsApiCore.js")
        client = read_text("qml/backend/NewsApiClient.qml")

        for endpoint in [
            "/index.php/apps/news/api/v1-2",
            "/folders",
            "/feeds",
            "/move",
            "/items?",
            "/items/read/multiple",
            "/items/unread/multiple",
            "/items/star/multiple",
            "/items/unstar/multiple",
        ]:
            self.assertIn(endpoint, core)

        self.assertIn('requestJson("GET"', client)
        self.assertIn('requestJson("PUT"', client)
        self.assertIn('requestJson("POST"', client)
        self.assertIn('requestJson("DELETE"', client)
        self.assertIn('requestForm("POST"', client)
        self.assertIn("request.open(method, url)", client)
        self.assertIn('"Authorization", "Basic " + Qt.btoa(userName + ":" + secret)', client)
        self.assertNotRegex(client, r"console\.log\([^\\n]*(secret|password|Secret|Password)")

    def test_feed_creation_matches_nextcloud_news_contract(self):
        core = read_text("qml/backend/NewsApiCore.js")
        client = read_text("qml/backend/NewsApiClient.qml")
        controller = read_text("qml/backend/NewsController.qml")
        page = read_text("qml/pages/NewsListPage.qml")

        self.assertIn("createFeedPayload", core)
        self.assertIn('"url"', core)
        self.assertIn('"folderId"', core)
        self.assertIn("function createFeed", client)
        self.assertIn("Content-Type\", \"application/x-www-form-urlencoded", client)
        self.assertIn("api.createFeed", controller)
        self.assertIn("onFeedCreated", controller)
        self.assertIn("Add feed", page)
        self.assertIn("addFeedPanelOpen", page)
        self.assertIn("openAddFeedPanel", page)
        self.assertIn('"openExternal": false', core)

    def test_feed_and_folder_management_contract(self):
        core = read_text("qml/backend/NewsApiCore.js")
        client = read_text("qml/backend/NewsApiClient.qml")
        controller = read_text("qml/backend/NewsController.qml")
        page = read_text("qml/pages/NewsListPage.qml")

        for snippet in [
            "createFolderPayload",
            "moveFeedPayload",
            "moveFeedUrl",
            "renameFeedUrl",
            "renameFeedPayload",
            "renameFolderPayload",
            "feedUrl",
            "folderUrl",
        ]:
            self.assertIn(snippet, core)
        for snippet in [
            "function createFolder",
            "function moveFeed",
            "function renameFeed",
            "function renameFolder",
            "function deleteFeed",
            "function deleteFolder",
        ]:
            self.assertIn(snippet, client)
            self.assertIn(snippet, controller)
        for snippet in ["folderCreated", "folderRenamed", "folderDeleted", "feedRenamed", "feedMoved", "feedDeleted"]:
            self.assertIn(snippet, client)
        self.assertIn("property int requestGeneration: 0", client)
        self.assertIn("folderCreated(result.folders, generation)", client)
        self.assertIn("folderDeleted(Number(folderId || 0), generation)", client)
        self.assertIn("failed(string message, int generation)", client)
        for snippet in ["onFolderCreated", "onFolderDeleted", "onFeedMoved", "onFeedDeleted"]:
            self.assertIn(snippet, controller)
        self.assertIn("cache.saveFolders(folders)", controller)
        self.assertIn("rebuildFolderFeedModels", controller)
        self.assertIn("foldersModel.append", controller)
        self.assertIn("feedsModel.append", controller)
        self.assertIn("deleteNextFeedInFolder", controller)
        self.assertIn("property int accountRequestGeneration: 0", controller)
        self.assertIn("function stopAccountActivity()", controller)
        self.assertIn("function isCurrentApiGeneration(generation)", controller)
        self.assertIn("ignored stale", controller)
        for snippet in [
            "feedOptionsDialog",
            "folderOptionsDialog",
            "renameFeedDialog",
            "renameFolderDialog",
            "deleteFeedConfirmDialog",
            "deleteFolderConfirmDialog",
            "New folder",
            "Move to folder",
            "Rename feed",
            "Rename folder",
            "Delete feed",
            "Delete folder",
        ]:
            self.assertIn(snippet, page)

    def test_star_payload_preserves_feed_id_and_guid_hash(self):
        core = read_text("qml/backend/NewsApiCore.js")

        self.assertIn('"feedId"', core)
        self.assertIn('"guidHash"', core)
        self.assertIn("starPayload", core)


class CacheAndSyncContractTests(unittest.TestCase):
    def test_cache_schema_tracks_folders_feeds_items_and_pending_state(self):
        cache = read_text("qml/backend/NewsCache.qml")

        for table in [
            "CREATE TABLE IF NOT EXISTS folders",
            "CREATE TABLE IF NOT EXISTS feeds",
            "CREATE TABLE IF NOT EXISTS items",
            "pending_state IS NULL OR pending_state = ''",
            "AND feed_id NOT IN",
            "function removeFeed",
            "function removeFolder",
            "pending_management",
            "function queueManagementOperation",
            "function loadPendingManagementOperations",
            "function removePendingManagementOperation",
            "function clearAllPendingItems",
            "function clearPendingManagementOperations",
            "existingOpenExternal",
            "pending_state",
            "guid_hash",
            "feed_id",
            "pub_date",
            "starred",
            "unread",
        ]:
            self.assertIn(table, cache)

    def test_controller_uses_cached_first_and_uploads_pending_before_pull(self):
        controller = read_text("qml/backend/NewsController.qml")

        self.assertIn("loadCached()", controller)
        self.assertIn("syncPendingThenPull", controller)
        self.assertIn("processNextManagementOperation", controller)
        self.assertIn("localStateUploadOnly", controller)
        self.assertIn("localStateUploadTimer", controller)
        self.assertIn("scheduleLocalStateUpload", controller)
        self.assertIn("uploadReadStatesNow", controller)
        self.assertIn("api.markItemsRead", controller)
        self.assertIn("handleApplicationDeactivated", controller)
        self.assertIn("uploadLocalStateOnly()", controller)
        self.assertIn("clearPendingInModels", controller)
        self.assertIn("updateLocalReadStateInModels", controller)
        self.assertIn("updateLocalStarStateInModels", controller)
        self.assertIn("queueCurrentManagementOperation", controller)
        self.assertIn("processNextPending", controller)
        self.assertIn("pendingChangeRows", controller)
        self.assertIn("retryPendingChanges", controller)
        self.assertIn("discardPendingChangesAndRefresh", controller)
        self.assertIn("api.fetchFolders", controller)
        self.assertIn("api.fetchFeeds", controller)
        self.assertIn("api.fetchItems", controller)
        self.assertIn("handleApplicationActivated", controller)
        self.assertIn("runtimeUserName", controller)
        self.assertIn("runtimeSecret", controller)

        api_client = read_text("qml/backend/NewsApiClient.qml")
        self.assertIn("signal itemStatesUploaded", api_client)
        self.assertIn("function markItemsRead", api_client)
        self.assertIn("idsPayload(itemIds)", api_client)

    def test_sync_planner_classifies_local_state(self):
        planner = read_text("qml/backend/SyncPlanner.js")

        self.assertIn('item.pendingState === "state"', planner)
        self.assertIn('item.pendingState === "star"', planner)


class UiContractTests(unittest.TestCase):
    def test_main_owns_one_shared_news_controller(self):
        main = read_text("qml/Main.qml")
        pages = read_text("qml/pages/NewsListPage.qml") + read_text("qml/pages/ArticleDetailPage.qml")

        self.assertEqual(main.count("NewsController {"), 1)
        self.assertIn("handleApplicationActivated", main)
        self.assertNotIn("NewsController {", pages)

    def test_news_list_has_android_inspired_affordances(self):
        page = read_text("qml/pages/NewsListPage.qml")
        controller = read_text("qml/backend/NewsController.qml")

        for snippet in [
            "\\u2630",
            "Search articles",
            "Refresh",
            "section.property: \"sectionKey\"",
            "displaySectionLabel",
            "markVisibleViewportArticlesRead",
            "section.property: \"groupLabel\"",
            "New folder name",
            "pendingAddFeedFolderName",
            "pendingFolderSelectTimer",
            "selectPendingAddFeedFolder",
            "addFeedCommitTimer",
            "addFeedCreateFolderCommitTimer",
            "Qt.inputMethod.commit()",
            "oskOverlap",
            "Clear feed URL",
            "Waiting for folder",
            "section === i18n.tr(\"Folders\")",
            "section === i18n.tr(\"Feeds\")",
            "userScrolledArticleList",
            "markAllFab",
            "markAllTarget",
            "Mark read",
            "Mark unread",
            "actionForOffset(cardContent.x)",
            "readStateBadgeLabel",
            "pendingBadgeLabel",
            "feedFaviconLink",
            "Unknown feed",
            "maximumLineCount: 2",
            "theme.palette.normal.background",
            "statusIconKind",
            "openStatusFromIcon",
            "ConflictResolutionPage.qml",
            "navigationRowSelected",
            "color: page.navigationRowSelected(model.type, model.id) ? \"white\" : theme.palette.normal.backgroundText",
            "visible: model.count > 0",
            "rightMargin: model.type === \"feed\" || model.type === \"folder\" ? units.gu(5) : 0",
            "toggleStar",
            "toggleRead",
            "markVisibleRead",
            "\\u2605",
            "pullRefreshThreshold",
            "ArticleDetailPage.qml",
            "AboutPage.qml",
            "SettingsPage.qml",
            "OpacityMask",
            "accountAvatarSource",
            "Rename feed",
            "Rename folder",
            "Open in browser",
        ]:
            self.assertIn(snippet, page)
        for snippet in ["All articles", "Unread", "Starred", "Folders", "Feeds", "Today", "Yesterday", "emitRequestedFolderIfAvailable(folders)", "setAutoSyncEnabled", "setSortOldestFirst", "setSearchIn", "leftId", "rightId", "sectionKeyForTimestamp"]:
            self.assertIn(snippet, controller)
        for snippet in ["feedForId", "item.feedTitle", "item.feedFaviconLink"]:
            self.assertIn(snippet, controller)
        for snippet in ["folderCreateRunning", "feedCreateRunning"]:
            self.assertIn(snippet, controller)
        self.assertNotIn("enabled: !newsController.folderCreateRunning && addFeedPanelFolderNameField.text.trim().length > 0", page)
        self.assertNotIn("id: statusStrip", page)
        self.assertNotIn("\\u2606", page)

    def test_pending_changes_conflict_page_is_registered(self):
        qrc = read_text("qml/qml.qrc")
        page = read_text("qml/pages/ConflictResolutionPage.qml")
        controller = read_text("qml/backend/NewsController.qml")

        self.assertIn("pages/ConflictResolutionPage.qml", qrc)
        for snippet in [
            "Pending changes",
            "pendingChangeRows",
            "Keep local",
            "Retry now",
            "Discard",
            "discardPendingChangesAndRefresh",
            "retryPendingChanges",
        ]:
            self.assertIn(snippet, page + controller)

    def test_account_page_has_editable_server_address_without_manual_login(self):
        page = read_text("qml/pages/AccountSelectionPage.qml")
        common_page = read_text("vendor/NextCommon/qml/NextCommon/AccountPage.qml")

        self.assertIn("NextCommon.AccountPage", page)
        self.assertIn("Server address", common_page)
        self.assertIn("serverUrlField", common_page)
        self.assertIn("serverUrlCommitTimer", common_page)
        self.assertIn("commitServerUrlInput", common_page)
        self.assertIn("This app uses Ubuntu Touch Online Accounts", common_page)
        self.assertNotIn("app password", page.lower() + common_page.lower())

    def test_settings_page_controls_sync_search_and_reading_options(self):
        page = read_text("qml/pages/SettingsPage.qml")
        qrc = read_text("qml/qml.qrc")
        controller = read_text("qml/backend/NewsController.qml")

        self.assertIn("pages/SettingsPage.qml", qrc)
        for snippet in [
            "Sync while app is active",
            "Sync on startup",
            "Active sync interval",
            "Oldest articles first",
            "Open articles in browser directly",
            "Reverse left/right actions",
            "Title",
            "Content",
            "Both",
        ]:
            self.assertIn(snippet, page)
        for snippet in [
            "function setSwipeActionLayout(value)",
            'property string swipeActionLayout: "ut"',
            "page.newsListPage.setSwipeActionLayout(normalized)",
            "enabled: newsController.autoSyncEnabled",
        ]:
            self.assertIn(snippet, page)
        self.assertNotIn("Mark articles read while scrolling", page)
        for snippet in [
            "autoSyncEnabled",
            "syncIntervalMinutes",
            "sortOldestFirst",
            "searchIn",
            "openInBrowserDirectly",
            "markReadWhileScrolling",
        ]:
            self.assertIn(snippet, controller)
        self.assertIn("property bool markReadWhileScrolling: false", controller)

    def test_article_list_supports_configurable_swipe_direction(self):
        page = read_text("qml/pages/NewsListPage.qml")

        for snippet in [
            "property string activeSwipeActionLayout",
            'property string swipeActionLayout: "ut"',
            "function actionForOffset(offset)",
            'page.activeSwipeActionLayout === "android" ? "star" : "read"',
            'page.activeSwipeActionLayout === "android" ? "read" : "star"',
            "function setSwipeActionLayout(value)",
            '"swipeActionLayout": page.activeSwipeActionLayout',
            '"newsListPage": page',
        ]:
            self.assertIn(snippet, page)

    def test_account_page_and_controller_match_avatar_contract(self):
        account_page = read_text("qml/pages/AccountSelectionPage.qml")
        common_page = read_text("vendor/NextCommon/qml/NextCommon/AccountPage.qml")
        controller = read_text("qml/backend/NewsController.qml")

        self.assertNotIn("Server from Ubuntu Touch account", account_page + common_page)
        self.assertIn("avatarUrl(accountSettings.serverUrl, userName)", common_page)
        self.assertIn("accountSettings.avatarUrl", common_page)
        self.assertIn("/index.php/avatar/", common_page)
        self.assertIn("accountSettings.avatarUrl", controller)
        self.assertIn("function avatarUrl", controller)

    def test_article_detail_has_read_and_star_actions(self):
        page = read_text("qml/pages/ArticleDetailPage.qml")
        cmake = read_text("CMakeLists.txt")
        main = read_text("main.cpp")
        export_page = read_text("qml/backend/ArticleShareExportPage.qml")
        bridge = read_text("ContentHubBridge.cpp")

        for snippet in [
            "Mark read",
            "Mark unread",
            "Star",
            "Unstar",
            "Open",
            "Share",
            "feedFavicon",
            "feedInitial",
            "Unknown feed",
            "Text.RichText",
            "non-starred",
            "#f6c343",
            "linkifyPlainText",
            "onLinkActivated: Qt.openUrlExternally(link)",
            "shareArticle",
            "ArticleShareExportPage.qml",
            "ArticleShareExportPageUbuntu.qml",
            "articleBodyRichText",
            "escapeHtml",
        ]:
            self.assertIn(snippet, page)
        self.assertNotIn("mailto:", page)
        self.assertNotIn("Share by email", page)
        self.assertNotIn("Open original link", page)
        self.assertIn("ContentHubBridge.cpp", cmake)
        self.assertIn("${PROJECT_NAME}-contenthub.json", cmake)
        self.assertIn("setContextProperty(QStringLiteral(\"contentHubBridge\")", main)
        self.assertIn("ContentHandler.Share", export_page)
        self.assertIn("item.text = shareText", export_page)
        self.assertIn("writeSharedTextFile", bridge)

    def test_about_page_records_version_license_and_disclaimer(self):
        page = read_text("qml/pages/AboutPage.qml")
        manifest = json.loads(read_text("manifest.json.in"))
        cmake = read_text("CMakeLists.txt")
        changelog = read_text("CHANGELOG.md")

        for snippet in [
            "nextnewsAppVersion",
            "Version %1",
            "MIT License",
            "Etherghost",
            "not affiliated",
            "qrc:/assets/logo.svg",
        ]:
            self.assertIn(snippet, page)
        self.assertIn('set(NEXTNEWS_VERSION "0.3.0")', cmake)
        self.assertIn("## 0.3.0", changelog)
        self.assertIn("## 0.2.0", changelog)
        self.assertIn("## 0.1.8", changelog)
        self.assertIn("## 0.1.7", changelog)
        self.assertIn("## 0.1.6", changelog)
        self.assertEqual(manifest["version"], "@NEXTNEWS_VERSION@")
        self.assertIn("## 0.1.5", changelog)
        self.assertIn("## 0.1.4", changelog)
        self.assertIn("## 0.1.2", changelog)
        self.assertIn("## 0.1.1", changelog)
        self.assertIn("## 0.1.0", changelog)


class DocumentationTests(unittest.TestCase):
    def test_docs_record_template_auth_api_and_status(self):
        readme = read_text("README.md")
        license_text = read_text("LICENSE")

        self.assertIn("same Ubuntu Touch development approach", readme)
        self.assertIn("Nextcloud app suite", readme)
        self.assertNotIn("technical implementation template", readme)
        self.assertIn("Ubuntu Touch Online Accounts only", readme)
        self.assertIn("/index.php/apps/news/api/v1-2/", readme)
        self.assertIn("MIT License", readme)
        self.assertIn("MIT License", license_text)

    def test_no_accidental_nextnotes_leftovers_in_runtime_files(self):
        runtime_files = [
            "manifest.json.in",
            "CMakeLists.txt",
            "main.cpp",
            "nextnews.accounts",
            "nextnews.apparmor",
            "nextnews.desktop.in",
            "qml/Main.qml",
            "qml/backend/NewsApiClient.qml",
            "qml/backend/NewsCache.qml",
            "qml/backend/NewsController.qml",
            "qml/pages/NewsListPage.qml",
            "qml/pages/ArticleDetailPage.qml",
        ]
        for path in runtime_files:
            self.assertNotIn("nextnotes", read_text(path).lower(), path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
