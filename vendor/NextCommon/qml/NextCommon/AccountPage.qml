import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import Lomiri.OnlineAccounts 2.0
import Qt.labs.settings 1.0
import "qrc:/NextCommon/UrlHelpers.js" as UrlHelpers
import "qrc:/NextCommon/TextHelpers.js" as TextHelpers

Page {
    id: page

    property string appName: ""
    property string logPrefix: appName
    property string appApplicationId: ""
    property string nextcloudServiceId: ""
    property string owncloudServiceId: ""

    signal accountAuthorized(int accountId, string displayName, string providerId, string serviceId, string serverUrl, string avatarUrl)

    property int selectedAccountId: 0
    property string selectedDisplayName: ""
    property string selectedServiceId: ""
    property var selectedAccount: null
    property string serverUrl: accountSettings.serverUrl
    property string pendingServerUrlAction: ""
    property bool authorizationRunning: false
    property bool waitingForSystemApproval: false
    property bool pageHasAppeared: false
    property string authorizationStatus: i18n.tr("Select an account and authorize it for %1.").arg(page.appName)
    readonly property real oskOverlap: Qt.inputMethod.visible && Qt.inputMethod.keyboardRectangle.height > 0
        ? Math.max(0, page.height - Qt.inputMethod.keyboardRectangle.y)
        : 0

    header: PageHeader {
        id: header
        title: i18n.tr("Accounts")
    }

    Settings {
        id: accountSettings
        category: "account"
        property int accountId: 0
        property string displayName: ""
        property string providerId: ""
        property string serviceId: ""
        property string serverUrl: ""
        property string avatarUrl: ""
    }

    AccountModel {
        id: accountModel
        applicationId: page.appApplicationId

        onReadyChanged: if (ready) page.restoreSelectedAccountFromSettings()
    }

    Connections {
        target: page.selectedAccount
        ignoreUnknownSignals: true
        onAuthenticationReply: page.handleAuthenticationReply(authenticationData)
    }

    Timer {
        id: serverUrlCommitTimer
        interval: 80
        repeat: false
        onTriggered: {
            page.serverUrl = serverUrlField.text
            page.saveServerUrl()
            var action = page.pendingServerUrlAction
            page.pendingServerUrlAction = ""
            if (action === "authenticate") {
                page.authenticateSelectedAccountAfterCommit()
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (page.pageHasAppeared) {
                page.refreshAccountModel()
            }
            page.pageHasAppeared = true
            if (page.waitingForSystemApproval) {
                retrySystemApprovalTimer.restart()
            }
        }
    }

    Connections {
        target: Qt.application
        onActiveChanged: {
            if (Qt.application.active && page.visible && page.pageHasAppeared) {
                page.refreshAccountModel()
                if (page.waitingForSystemApproval) {
                    retrySystemApprovalTimer.restart()
                }
            }
        }
    }

    Timer {
        id: retrySystemApprovalTimer
        interval: 900
        repeat: false
        onTriggered: page.retryAfterSystemApproval()
    }

    Component {
        id: openSystemAccountsDialog

        Dialog {
            id: dialog
            title: i18n.tr("Allow account access")
            text: page.systemAccountsDialogText()

            Button {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Open System Settings")
                onClicked: {
                    PopupUtils.close(dialog)
                    page.openSystemAccountsSettings()
                }
            }

            Button {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("OK")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Flickable {
        id: pageFlickable
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
            topMargin: header.height + units.gu(2)
            bottomMargin: units.gu(2) + page.oskOverlap
        }
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.DragAndOvershootBounds

        ColumnLayout {
            id: contentColumn
            width: pageFlickable.width
            spacing: units.gu(1.25)

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Account")
                textSize: Label.Large
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(8)
                radius: units.gu(0.5)
                color: "transparent"
                border.width: 1
                border.color: "#7a7a7a"

                RowLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: units.gu(1)
                    }
                    spacing: units.gu(1)

                    Rectangle {
                        Layout.preferredWidth: units.gu(5)
                        Layout.preferredHeight: units.gu(5)
                        radius: units.gu(2.5)
                        color: "#2c7fb8"

                        Label {
                            anchors.centerIn: parent
                            text: page.accountInitial()
                            color: "white"
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(0.25)

                        Label {
                            Layout.fillWidth: true
                            text: page.displayAccountName()
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Label {
                            Layout.fillWidth: true
                            text: page.displayServerUrl()
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: 0.75
                        }
                    }

                    Label {
                        text: page.accountReady() ? "✓" : "!"
                        color: page.accountReady() ? "#2f7d32" : "#c65d00"
                        font.pixelSize: units.gu(2.4)
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Server address")
                font.bold: true
                elide: Text.ElideRight
            }

            TextField {
                id: serverUrlField
                Layout.fillWidth: true
                placeholderText: i18n.tr("https://cloud.example.com")
                text: page.serverUrl.length > 0 ? page.serverUrl : accountSettings.serverUrl
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                onTextChanged: page.serverUrl = text
                onAccepted: page.commitServerUrlInput("")
            }

            Label {
                Layout.fillWidth: true
                text: i18n.tr("This app uses Ubuntu Touch Online Accounts. Edit this only if the system account did not expose the correct server address.")
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                opacity: 0.68
            }

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Available accounts")
                font.bold: true
                elide: Text.ElideRight
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(3)

                Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("Add another account in System Settings")
                    color: theme.palette.normal.backgroundText
                    opacity: 0.82
                    font.underline: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.openSystemAccountsSettings()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: noAccountsColumn.implicitHeight + units.gu(2)
                visible: accountModel.ready && page.matchingAccountCount() === 0
                radius: units.gu(0.5)
                color: "transparent"
                border.width: 1
                border.color: "#c65d00"

                ColumnLayout {
                    id: noAccountsColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: units.gu(1)
                    }
                    spacing: units.gu(0.5)

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("No Nextcloud account found")
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Add a Nextcloud or ownCloud account in Ubuntu Touch System Settings > Accounts, and allow %1 to use it. Then return here and select it.").arg(page.appName)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        opacity: 0.82
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: units.gu(5)

                        Label {
                            anchors.centerIn: parent
                            text: i18n.tr("Open System Settings")
                            color: theme.palette.normal.backgroundText
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.openSystemAccountsSettings()
                        }
                    }
                }
            }

            ListView {
                id: accountsList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.max(contentHeight, units.gu(7)), units.gu(24))
                clip: true
                model: accountModel

                delegate: ListItem {
                    id: row

                    readonly property bool isMatchingService: model.serviceId === page.nextcloudServiceId || model.serviceId === page.owncloudServiceId
                    readonly property bool isSelected: (page.selectedAccountId === model.accountId && page.selectedServiceId === model.serviceId)
                        || (page.selectedAccountId <= 0
                            && accountSettings.accountId === model.accountId
                            && accountSettings.serviceId === model.serviceId)

                    height: visible ? Math.max(units.gu(7), content.implicitHeight + units.gu(1.6)) : 0
                    visible: isMatchingService
                    color: isSelected ? Qt.rgba(0.17, 0.5, 0.72, 0.16) : "transparent"

                    enabled: !page.authorizationRunning

                    onClicked: {
                        if (page.authorizationRunning) {
                            return
                        }

                        page.selectAccount(model.account, model.accountId, model.displayName, model.serviceId, model.settings)
                    }

                    RowLayout {
                        id: content
                        x: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, row.width - units.gu(2))
                        spacing: units.gu(1)

                        Rectangle {
                            Layout.preferredWidth: units.gu(4.5)
                            Layout.preferredHeight: units.gu(4.5)
                            radius: units.gu(2.25)
                            color: row.isSelected ? "#2c7fb8" : "transparent"
                            border.width: 1
                            border.color: "#7a7a7a"

                            Label {
                                anchors.centerIn: parent
                                text: String(model.displayName || "?").charAt(0).toUpperCase()
                                color: row.isSelected ? "white" : theme.palette.normal.backgroundText
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: units.gu(0.25)

                            Label {
                                Layout.fillWidth: true
                                text: model.displayName
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Label {
                                Layout.fillWidth: true
                                text: page.accountRowSubtitle(model.serviceId, model.settings)
                                textSize: Label.Small
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                opacity: 0.72
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(5)
                radius: units.gu(0.6)
                color: page.selectedAccountId > 0 && !page.authorizationRunning ? "#2c7fb8" : "transparent"
                border.width: page.selectedAccountId > 0 && !page.authorizationRunning ? 0 : 1
                border.color: "#7a7a7a"
                enabled: page.selectedAccountId > 0 && !page.authorizationRunning

                Label {
                    anchors.centerIn: parent
                    text: page.authorizationRunning ? i18n.tr("Verifying account...") : i18n.tr("Verify selected account")
                    color: parent.enabled ? "white" : theme.palette.normal.backgroundText
                    opacity: parent.enabled ? 1.0 : 0.55
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.enabled
                    onClicked: page.authenticateSelectedAccount()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(5)
                visible: page.waitingForSystemApproval
                radius: units.gu(0.6)
                color: "#2c7fb8"

                Label {
                    anchors.centerIn: parent
                    text: i18n.tr("How to allow this account")
                    color: "white"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: PopupUtils.open(openSystemAccountsDialog)
                }
            }

            Label {
                Layout.fillWidth: true
                text: authorizationStatus
                wrapMode: Text.WordWrap
                maximumLineCount: 5
                opacity: 0.82
            }
        }
    }

    function matchingAccountCount() {
        var count = 0
        for (var i = 0; i < accountModel.count; ++i) {
            var serviceId = accountModel.get(i, "serviceId")
            if (serviceId === page.nextcloudServiceId || serviceId === page.owncloudServiceId) {
                count += 1
            }
        }
        return count
    }

    function providerIdForService(serviceId) {
        if (serviceId === page.nextcloudServiceId) return "nextcloud"
        if (serviceId === page.owncloudServiceId) return "owncloud"
        return ""
    }

    function accountRowSubtitle(serviceId, settings) {
        var provider = page.providerIdForService(serviceId)
        var server = page.serverUrlFromSettings(settings)
        if (server.length > 0) {
            return provider.length > 0 ? provider + " - " + server : server
        }
        return provider
    }

    function selectAccount(accountObject, accountId, displayName, serviceId, settings) {
        selectedAccount = accountObject
        selectedAccountId = accountId
        selectedDisplayName = displayName
        selectedServiceId = serviceId

        var resolvedUrl = serverUrlFromSettings(settings)
        if (resolvedUrl.length === 0) {
            resolvedUrl = inferServerUrlFromDisplayName(displayName)
        }
        if (resolvedUrl.length === 0 && accountSettings.accountId === accountId) {
            resolvedUrl = normalizeServerUrl(accountSettings.serverUrl)
        }
        serverUrl = resolvedUrl
        serverUrlField.text = serverUrl

        authorizationStatus = i18n.tr("Selected %1. Verifying authorization...").arg(displayName)
        page.commitServerUrlInput("authenticate")
    }

    function restoreSelectedAccountFromSettings() {
        if (selectedAccountId > 0 || accountSettings.accountId <= 0 || accountSettings.serviceId.length === 0) {
            return
        }

        for (var i = 0; i < accountModel.count; ++i) {
            if (accountModel.get(i, "accountId") === accountSettings.accountId
                    && accountModel.get(i, "serviceId") === accountSettings.serviceId) {
                selectedAccount = accountModel.get(i, "account")
                selectedAccountId = accountSettings.accountId
                selectedDisplayName = accountSettings.displayName
                selectedServiceId = accountSettings.serviceId
                serverUrl = normalizeServerUrl(accountSettings.serverUrl)
                serverUrlField.text = serverUrl
                authorizationStatus = i18n.tr("Saved account selected. Verify again if needed.")
                return
            }
        }
    }

    function serverUrlFromSettings(settings) {
        var values = [
            settings ? settings.host : "",
            settings ? settings.Host : "",
            settings ? settings.server : "",
            settings ? settings.serverUrl : "",
            settings ? settings.url : "",
            settings ? settings.Url : ""
        ]

        for (var i = 0; i < values.length; ++i) {
            var url = normalizeServerUrl(values[i])
            if (url.length > 0) {
                return url
            }
        }

        return ""
    }

    function inferServerUrlFromDisplayName(displayName) {
        var value = String(displayName || "").trim()
        var atIndex = value.lastIndexOf("@")
        if (atIndex < 0 || atIndex === value.length - 1) {
            return ""
        }

        var host = value.slice(atIndex + 1)
        host = host.replace(/[<>()\[\],;]/g, "").trim()
        return normalizeServerUrl(host)
    }

    function authenticateSelectedAccount() {
        page.commitServerUrlInput("authenticate")
    }

    function authenticateSelectedAccountAfterCommit() {
        if (selectedAccountId <= 0 || !selectedAccount) {
            authorizationStatus = i18n.tr("Select an account first.")
            return
        }

        page.authorizationRunning = true
        authorizationStatus = i18n.tr("Verifying Online Accounts authorization...")
        selectedAccount.authenticate({})
    }

    function handleAuthenticationReply(authenticationData) {
        page.authorizationRunning = false

        if (authenticationData && authenticationData.errorCode !== undefined) {
            handleAuthenticationError(authenticationData)
            return
        }

        page.waitingForSystemApproval = false
        var userName = firstValue(authenticationData, ["UserName", "Username", "userName", "username"])

        if (displayServerUrlIsMissing()) {
            authorizationStatus = i18n.tr("Authorization succeeded, but the Ubuntu Touch account did not expose a server address for %1.").arg(page.appName)
        } else {
            authorizationStatus = i18n.tr("Authorization succeeded for %1. Credentials are available to the app, but were not displayed or stored.").arg(page.appName)
        }

        accountSettings.accountId = page.selectedAccountId
        accountSettings.displayName = page.selectedDisplayName
        accountSettings.providerId = page.providerIdForService(page.selectedServiceId)
        accountSettings.serviceId = page.selectedServiceId
        accountSettings.serverUrl = page.normalizeServerUrl(page.serverUrl)
        accountSettings.avatarUrl = page.avatarUrl(accountSettings.serverUrl, userName)
        page.accountAuthorized(
            accountSettings.accountId,
            accountSettings.displayName,
            accountSettings.providerId,
            accountSettings.serviceId,
            accountSettings.serverUrl,
            accountSettings.avatarUrl
        )
    }

    function handleAuthenticationError(authenticationData) {
        var errorCode = authenticationData.errorCode
        if (errorCode === Account.ErrorCodePermissionDenied) {
            page.waitingForSystemApproval = true
            authorizationStatus = i18n.tr("Ubuntu Touch Online Accounts did not allow %1 to use this account yet. Check that %1 is enabled for this account in System Settings > Accounts, then return here.").arg(page.appName)
            page.openSystemAccountsHelp()
        } else if (errorCode === Account.ErrorCodeUserCanceled) {
            authorizationStatus = i18n.tr("Authorization was canceled.")
        } else {
            page.waitingForSystemApproval = true
            authorizationStatus = i18n.tr("Authorization failed. If the system did not show an Online Accounts prompt, open System Settings > Accounts and allow %1 for this account, then try again.").arg(page.appName)
            page.openSystemAccountsHelp()
        }
    }

    function clearSelectedAccount() {
        page.authorizationRunning = false
        page.waitingForSystemApproval = false
        selectedAccount = null
        selectedAccountId = 0
        selectedDisplayName = ""
        selectedServiceId = ""
    }

    function systemAccountsDialogText() {
        if (page.matchingAccountCount() === 0) {
            return i18n.tr("Open Ubuntu Touch System Settings manually, go to Accounts, add a Nextcloud or ownCloud account, then return to %1 and select it.").arg(page.appName)
        }

        var accountName = page.selectedDisplayName.length > 0
            ? page.selectedDisplayName
            : accountSettings.displayName
        if (accountName.length > 0) {
            return i18n.tr("Open Ubuntu Touch System Settings manually, go to Accounts, select %1, allow %2 for that account, then return here. %2 will verify it automatically.")
                .arg(accountName).arg(page.appName)
        }

        return i18n.tr("Open Ubuntu Touch System Settings manually, go to Accounts, select the Nextcloud account, allow %1 for that account, then return here. %1 will verify it automatically.").arg(page.appName)
    }

    function openSystemAccountsSettings() {
        Qt.openUrlExternally("settings:///system/online-accounts")
    }

    function openSystemAccountsHelp() {
        Qt.callLater(function() {
            if (page.waitingForSystemApproval) {
                PopupUtils.open(openSystemAccountsDialog)
            }
        })
    }

    function refreshAccountModel() {
        // Manager (and its cached account list) is only rebuilt when
        // applicationId actually changes, so toggle it to force a fresh
        // query after the user may have changed grants in System Settings.
        accountModel.applicationId = ""
        accountModel.applicationId = page.appApplicationId
    }

    function retryAfterSystemApproval() {
        if (!page.waitingForSystemApproval || page.authorizationRunning || selectedAccountId <= 0) {
            return
        }

        authorizationStatus = i18n.tr("Verifying Online Accounts authorization...")
        page.waitingForSystemApproval = false
        page.authenticateSelectedAccountAfterCommit()
    }

    function commitServerUrlInput(action) {
        pendingServerUrlAction = action || ""
        Qt.inputMethod.commit()
        serverUrlField.focus = false
        serverUrlCommitTimer.restart()
    }

    function saveServerUrl() {
        var url = normalizeServerUrl(serverUrl)
        serverUrl = url
        accountSettings.serverUrl = url
    }

    function displayAccountName() {
        if (selectedDisplayName.length > 0) {
            return selectedDisplayName
        }
        if (accountSettings.displayName.length > 0) {
            return accountSettings.displayName
        }
        return i18n.tr("No account selected")
    }

    function displayServerUrl() {
        var url = normalizeServerUrl(serverUrl)
        if (url.length > 0) {
            return url
        }
        if (accountSettings.serverUrl.length > 0) {
            return accountSettings.serverUrl
        }
        return i18n.tr("The selected Ubuntu Touch account did not expose a server address.")
    }

    function displayServerUrlIsMissing() {
        if (selectedAccountId > 0) {
            return normalizeServerUrl(serverUrl).length === 0
        }
        return normalizeServerUrl(accountSettings.serverUrl).length === 0
    }

    function accountReady() {
        return (selectedAccountId > 0 || accountSettings.accountId > 0)
            && !displayServerUrlIsMissing()
    }

    function accountInitial() {
        var name = displayAccountName()
        if (name.length === 0 || name === i18n.tr("No account selected")) {
            return "?"
        }
        return name.charAt(0).toUpperCase()
    }

    function normalizeServerUrl(value) {
        var url = UrlHelpers.normalizeServerUrl(value)
        if (url.length === 0) {
            return ""
        }
        if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0) {
            return url
        }
        return "https://" + url
    }

    function avatarUrl(serverUrl, userName) {
        if (!serverUrl || !userName) {
            return ""
        }
        return String(serverUrl).replace(/\/+$/, "") + "/index.php/avatar/" + encodeURIComponent(userName) + "/64"
    }

    function objectKeys(value) {
        return TextHelpers.objectKeys(value)
    }

    function firstValue(value, names) {
        return TextHelpers.firstValue(value, names)
    }

    function hasValue(value) {
        return TextHelpers.hasValue(value)
    }
}
