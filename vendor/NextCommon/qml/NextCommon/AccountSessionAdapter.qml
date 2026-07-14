import QtQuick 2.7
import Lomiri.OnlineAccounts 2.0
import Qt.labs.settings 1.0

Item {
    id: adapter

    property string logPrefix: "NextApp"
    property int cachedAccountId: 0
    property string cachedServiceId: ""
    property string cachedServerUrl: ""
    property string cachedUserName: ""
    property string cachedSecret: ""
    property int currentAccountId: 0
    property string currentProviderId: ""
    property string currentServiceId: ""
    property string currentServerUrl: ""
    property int pendingAuthAccountId: 0
    property string pendingAuthServiceId: ""
    property string pendingAuthServerUrl: ""
    property var pendingAccount: null
    property var pendingCallback: null
    property bool pendingModelReady: false
    property bool envTestAuthEnabled: typeof desktopTestAuthEnabled !== "undefined" && desktopTestAuthEnabled
    property string envTestServerUrl: typeof desktopTestServerUrl !== "undefined" ? desktopTestServerUrl : ""
    property string envTestUserName: typeof desktopTestUserName !== "undefined" ? desktopTestUserName : ""
    property string envTestSecret: typeof desktopTestSecret !== "undefined" ? desktopTestSecret : ""

    signal authenticated(string userName, string secret, string serverUrl, int accountId, string serviceId)
    signal failed(string message)

    Settings {
        id: accountSettings
        category: "account"
        property int accountId: 0
        property string displayName: ""
        property string providerId: ""
        property string serviceId: ""
        property string serverUrl: ""
    }

    AccountModel {
        id: accountModel

        onReadyChanged: {
            if (ready && adapter.pendingModelReady) {
                adapter.pendingModelReady = false
                adapter.authenticate()
            }
        }
    }

    Connections {
        target: adapter.pendingAccount
        ignoreUnknownSignals: true
        onAuthenticationReply: adapter.handleAuthenticationReply(authenticationData)
    }

    function authenticate() {
        if (envTestAuthEnabled) {
            var testServerUrl = normalizeServerUrl(envTestServerUrl)
            if (testServerUrl.length === 0 || envTestUserName.length === 0 || envTestSecret.length === 0) {
                failed(i18n.tr("Desktop test credentials are incomplete."))
                return
            }

            cachedAccountId = -1
            cachedServiceId = "desktop-test-env"
            cachedServerUrl = testServerUrl
            cachedUserName = envTestUserName
            cachedSecret = envTestSecret
            authenticated(cachedUserName, cachedSecret, cachedServerUrl, cachedAccountId, cachedServiceId)
            if (pendingCallback) {
                var callback = pendingCallback
                pendingCallback = null
                callback(cachedUserName, cachedSecret, cachedServerUrl, cachedAccountId, cachedServiceId)
            }
            return
        }

        if (effectiveAccountId() <= 0 || effectiveServiceId().length === 0) {
            failed(i18n.tr("No account selected. Open Account first and authorize a Nextcloud account."))
            return
        }

        var serverUrl = normalizeServerUrl(effectiveServerUrl())
        if (serverUrl.length === 0) {
            failed(i18n.tr("No server URL configured. Open Account and authorize the OS account."))
            return
        }

        if (hasCachedCredentials(serverUrl)) {
            authenticated(cachedUserName, cachedSecret, cachedServerUrl, cachedAccountId, cachedServiceId)
            if (pendingCallback) {
                var callback = pendingCallback
                pendingCallback = null
                callback(cachedUserName, cachedSecret, cachedServerUrl, cachedAccountId, cachedServiceId)
            }
            return
        }

        if (!accountModel.ready) {
            pendingModelReady = true
            failed(i18n.tr("Waiting for Online Accounts..."))
            return
        }

        var account = findSelectedAccount()
        if (!account) {
            failed(i18n.tr("Selected Online Accounts service was not found. Open Account and verify the account again."))
            return
        }

        pendingAccount = account
        pendingAuthAccountId = effectiveAccountId()
        pendingAuthServiceId = effectiveServiceId()
        pendingAuthServerUrl = serverUrl
        account.authenticate({})
    }

    function withCredentials(callback) {
        pendingCallback = callback
        authenticate()
    }

    function setAccount(accountId, providerId, serviceId, serverUrl) {
        var normalizedServerUrl = normalizeServerUrl(serverUrl)
        var accountChanged = currentAccountId !== accountId
            || currentProviderId !== (providerId || "")
            || currentServiceId !== (serviceId || "")
            || currentServerUrl !== normalizedServerUrl

        if (accountChanged) {
            pendingModelReady = false
            pendingCallback = null
            cachedAccountId = 0
            cachedServiceId = ""
            cachedServerUrl = ""
            cachedUserName = ""
            cachedSecret = ""
            pendingAuthAccountId = 0
            pendingAuthServiceId = ""
            pendingAuthServerUrl = ""
            pendingAccount = null
        }

        currentAccountId = accountId
        currentProviderId = providerId || ""
        currentServiceId = serviceId || ""
        currentServerUrl = normalizedServerUrl
    }

    function handleAuthenticationReply(authenticationData) {
        if (!pendingAuthMatchesCurrent()) {
            return
        }

        if (authenticationData && authenticationData.errorCode !== undefined) {
            var errorCode = authenticationData.errorCode
            if (errorCode === Account.ErrorCodePermissionDenied) {
                failed(i18n.tr("This app is no longer allowed to use this account. Open System Settings > Accounts, allow it again, then try again."))
            } else if (errorCode === Account.ErrorCodeUserCanceled) {
                failed(i18n.tr("Authorization was canceled."))
            } else {
                failed(i18n.tr("Authentication failed. Open Account and verify the account again."))
            }
            return
        }

        var userName = firstValue(authenticationData, ["UserName", "Username", "userName", "username"])
        var secret = firstValue(authenticationData, ["Secret", "Password", "password", "secret"])

        if (!userName || !secret) {
            failed(i18n.tr("Authentication succeeded, but the required Online Accounts credentials were not available."))
            return
        }

        cachedAccountId = pendingAuthAccountId
        cachedServiceId = pendingAuthServiceId
        cachedServerUrl = pendingAuthServerUrl
        cachedUserName = userName
        cachedSecret = secret

        authenticated(userName, secret, cachedServerUrl, cachedAccountId, cachedServiceId)
        if (pendingCallback) {
            var callback = pendingCallback
            pendingCallback = null
            callback(userName, secret, cachedServerUrl, cachedAccountId, cachedServiceId)
        }
    }

    function findSelectedAccount() {
        var accountId = effectiveAccountId()
        var serviceIdSetting = effectiveServiceId()
        for (var i = 0; i < accountModel.count; ++i) {
            if (accountModel.get(i, "accountId") === accountId && accountModel.get(i, "serviceId") === serviceIdSetting) {
                return accountModel.get(i, "account")
            }
        }
        return null
    }

    function hasCachedCredentials(serverUrl) {
        return cachedAccountId === effectiveAccountId()
            && cachedServiceId === effectiveServiceId()
            && cachedServerUrl === serverUrl
            && cachedUserName.length > 0
            && cachedSecret.length > 0
    }

    function pendingAuthMatchesCurrent() {
        return pendingAuthAccountId === effectiveAccountId()
            && pendingAuthServiceId === effectiveServiceId()
            && pendingAuthServerUrl === normalizeServerUrl(effectiveServerUrl())
    }

    function effectiveAccountId() {
        return currentAccountId > 0 ? currentAccountId : accountSettings.accountId
    }

    function effectiveProviderId() {
        return currentProviderId.length > 0 ? currentProviderId : accountSettings.providerId
    }

    function effectiveServiceId() {
        return currentServiceId.length > 0 ? currentServiceId : accountSettings.serviceId
    }

    function effectiveServerUrl() {
        return currentServerUrl.length > 0 ? currentServerUrl : accountSettings.serverUrl
    }

    function normalizeServerUrl(value) {
        if (!value) {
            return ""
        }
        var url = String(value).trim()
        while (url.length > 0 && url.charAt(url.length - 1) === "/") {
            url = url.slice(0, -1)
        }
        if (url.length === 0) {
            return ""
        }
        if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0) {
            return url
        }
        return "https://" + url
    }

    function firstValue(value, names) {
        if (!value) {
            return ""
        }
        for (var i = 0; i < names.length; ++i) {
            if (value[names[i]] !== undefined && value[names[i]] !== null && String(value[names[i]]).length > 0) {
                return String(value[names[i]])
            }
        }
        return ""
    }

    function objectKeys(value) {
        var keys = []
        if (!value) {
            return keys
        }
        for (var key in value) {
            keys.push(key)
        }
        return keys.sort()
    }

    function hasValue(value) {
        return value !== undefined && value !== null && String(value).length > 0 ? "true" : "false"
    }

    function maskedIdentity(value) {
        var text = String(value || "")
        if (text.length === 0) {
            return "<none>"
        }
        if (text.indexOf("@") > 0) {
            var parts = text.split("@")
            return maskPart(parts[0]) + "@" + maskPart(parts.slice(1).join("@"))
        }
        return maskPart(text)
    }

    function maskPart(value) {
        var text = String(value || "")
        if (text.length <= 2) {
            return "**"
        }
        return text.charAt(0) + "***" + text.charAt(text.length - 1) + "(" + text.length + ")"
    }

}
