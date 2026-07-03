import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_text(path):
    return (ROOT / path).read_text(encoding="utf-8")


class NextCommonContractTests(unittest.TestCase):
    def test_expected_structure_exists(self):
        for path in [
            "README.md",
            "LICENSE",
            "docs/design-guide.md",
            "docs/integration-guide.md",
            "docs/versioning.md",
            "assets/icons/icon-style-guide.md",
            "qml/NextCommon/qmldir",
            "qml/NextCommon/VERSION",
            "qml/NextCommon/AboutPage.qml",
            "qml/NextCommon/LanguagePage.qml",
            "qml/NextCommon/AccountPage.qml",
            "qml/NextCommon/AccountSessionAdapter.qml",
            "qml/NextCommon/MainTopBar.qml",
            "qml/NextCommon/DrawerShell.qml",
            "qml/NextCommon/DrawerNavItem.qml",
            "qml/NextCommon/SettingsShell.qml",
            "qml/NextCommon/SettingsCard.qml",
            "qml/NextCommon/AvatarButton.qml",
            "qml/NextCommon/SyncBadge.qml",
            "js/DateFormat.js",
            "js/UrlHelpers.js",
            "js/TextHelpers.js",
            "js/LanguageHelpers.js",
        ]:
            self.assertTrue((ROOT / path).exists(), path)

    def test_generic_controls_do_not_live_in_nextcommon(self):
        for path in [
            "qml/NextCommon/AppButton.qml",
            "qml/NextCommon/ConfirmDialog.qml",
            "qml/NextCommon/EmptyState.qml",
            "qml/NextCommon/SectionHeader.qml",
            "qml/NextCommon/StatusRow.qml",
            "qml/NextCommon/CalendarDatePicker.qml",
            "qml/NextCommon/TimePicker.qml",
            "qml/NextCommon/ReorderableListView.qml",
            "qml/NextCommon/FlatActionButton.qml",
            "qml/NextCommon/FlatStepButton.qml",
        ]:
            self.assertFalse((ROOT / path).exists(), path)

        readme = read_text("README.md")
        guide = read_text("docs/integration-guide.md")
        self.assertIn("belong in `UTControls`, not in", readme)
        self.assertIn("NextCommon. Apps should vendor both modules", readme)
        self.assertIn("Use the", guide)
        self.assertIn("separate `UTControls` module", guide)
        self.assertNotIn("NextCommon/ReorderableListView.qml", guide)
        self.assertNotIn("NextCommon/CalendarDatePicker.qml", guide)

    def test_source_level_only_policy_is_documented(self):
        readme = read_text("README.md")
        guide = read_text("docs/integration-guide.md")
        self.assertIn("not a runtime shared library", readme)
        self.assertIn("git submodule", readme)
        self.assertIn("git submodule add", readme)
        self.assertIn("Do not put test credentials", guide)
        self.assertIn("Do not add AppArmor policy", guide)
        self.assertIn("Do not add a shared system package", guide)

    def test_qmldir_exports_only_nextcommon_scope(self):
        qmldir = read_text("qml/NextCommon/qmldir")
        for exported in [
            "AboutPage",
            "AccountPage",
            "AccountSessionAdapter",
            "AvatarButton",
            "DrawerNavItem",
            "DrawerShell",
            "LanguagePage",
            "MainTopBar",
            "SettingsCard",
            "SettingsShell",
            "SyncBadge",
        ]:
            self.assertIn(f"{exported} 1.0 {exported}.qml", qmldir)

        for forbidden in [
            "AppButton",
            "ConfirmDialog",
            "EmptyState",
            "SectionHeader",
            "StatusRow",
            "CalendarDatePicker",
            "TimePicker",
            "ReorderableListView",
            "FlatActionButton",
            "FlatStepButton",
        ]:
            self.assertNotIn(forbidden, qmldir)

        self.assertEqual(read_text("qml/NextCommon/VERSION").strip(), "0.2.1")

    def test_components_are_app_agnostic(self):
        combined = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (ROOT / "qml/NextCommon").glob("*.qml")
        )
        for forbidden in [
            "NextNotes",
            "NextNews",
            "NextTasks",
            "NextDeck",
            "nextnotes",
            "nextnews",
            "nexttasks",
            "nextdeck",
        ]:
            self.assertNotIn(forbidden, combined)
        self.assertNotIn("qsTr(", combined)
        self.assertNotIn("console.log", combined)

    def test_account_flow_never_opens_provider_login(self):
        account = read_text("qml/NextCommon/AccountPage.qml")
        session = read_text("qml/NextCommon/AccountSessionAdapter.qml")
        combined = account + "\n" + session

        self.assertIn("AccountServiceModel", account)
        self.assertIn("AccountService", account)
        self.assertIn("function openSystemAccountsSettings()", account)
        self.assertIn('Qt.openUrlExternally("settings:///system/online-accounts")', account)
        self.assertIn("function openSystemAccountsHelp()", account)
        self.assertIn("visible: page.waitingForSystemApproval", account)
        self.assertIn("selectedEnabled || selectedHasServiceHandle", account)
        self.assertIn("if (!selectedEnabled && !selectedHasServiceHandle)", account)

        self.assertIn("signal authenticated(string userName, string secret, string serverUrl, int accountId, string serviceId)", session)
        self.assertIn("function withCredentials(callback)", session)
        self.assertIn("function setAccount(", session)
        self.assertIn("cachedSecret = \"\"", session)

        for forbidden in [
            "Lomiri.OnlineAccounts.Client",
            "\n    Setup {",
            "accountSetup.exec()",
            "selectedService.updateServiceEnabled(true)",
            "repairSignOnAccessBeforePrompt",
            "signOnRepairAttemptCount",
        ]:
            self.assertNotIn(forbidden, combined)

    def test_shell_components_keep_expected_contracts(self):
        self.assertIn("property string avatarUrl", read_text("qml/NextCommon/AvatarButton.qml"))

        topbar = read_text("qml/NextCommon/MainTopBar.qml")
        self.assertIn("signal menuClicked()", topbar)
        self.assertIn("signal searchChanged(string text)", topbar)
        self.assertIn("signal filterClicked()", topbar)
        self.assertIn("signal statusClicked()", topbar)
        self.assertIn("signal accountClicked()", topbar)
        self.assertIn("AvatarButton", topbar)

        drawer = read_text("qml/NextCommon/DrawerShell.qml")
        self.assertIn("property string appName", drawer)
        self.assertIn("property var bottomItems", drawer)
        self.assertIn("default property alias content", drawer)
        self.assertIn("Flickable", drawer)
        self.assertIn("DrawerNavItem", drawer)
        self.assertIn("signal closeClicked()", drawer)
        self.assertIn("signal bottomItemClicked(string pageUrl)", drawer)

        settings_shell = read_text("qml/NextCommon/SettingsShell.qml")
        self.assertIn("Flickable", settings_shell)
        self.assertIn("default property alias content", settings_shell)
        self.assertIn("PageHeader", settings_shell)

        settings_card = read_text("qml/NextCommon/SettingsCard.qml")
        self.assertIn("default property alias content", settings_card)
        self.assertIn("border.width: 1", settings_card)

        language = read_text("qml/NextCommon/LanguagePage.qml")
        self.assertIn("property string appName", language)
        self.assertIn("property var languageOptions", language)
        self.assertIn("Qt.labs.settings", language)
        self.assertIn("ListView", language)
        self.assertIn("languageCode", language)
        self.assertIn("will follow the system language", language)

    def test_about_page_supports_contributors_and_disclaimer_section(self):
        about = read_text("qml/NextCommon/AboutPage.qml")
        self.assertIn("property string contributorsText", about)
        self.assertIn('i18n.tr("Contributors")', about)
        self.assertIn("visible: page.contributorsText.length > 0", about)
        self.assertIn('i18n.tr("Disclaimer")', about)
        self.assertLess(about.index('i18n.tr("License")'), about.index('i18n.tr("Disclaimer")'))

    def test_versioning_policy_allows_per_app_pins(self):
        readme = read_text("README.md")
        guide = read_text("docs/integration-guide.md")
        versioning = read_text("docs/versioning.md")
        self.assertIn("may intentionally use different NextCommon versions", readme)
        self.assertIn("Different apps in the NextApps suite may intentionally use different", guide)
        self.assertIn("Each app pins the exact NextCommon commit/version", versioning)
        self.assertIn("Do not edit vendored NextCommon files inside an app", versioning)


if __name__ == "__main__":
    unittest.main()
