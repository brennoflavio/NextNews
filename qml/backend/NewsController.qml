import QtQuick 2.7
import Qt.labs.settings 1.0
import "SyncPlanner.js" as SyncPlanner

Item {
    id: controller

    property bool loading: false
    property bool syncRunning: false
    property bool folderCreateRunning: false
    property bool feedCreateRunning: false
    property bool hasCachedItems: false
    property string statusText: ""
    property string syncStateText: i18n.tr("Idle")
    property string syncStateColor: "#5a8f3c"
    property string selectedFilterType: "all"
    property int selectedFilterId: 0
    property string selectedFilterLabel: i18n.tr("All articles")
    property string searchQuery: ""
    property string accountAvatarUrl: ""
    property int pendingCount: 0
    property int visibleUnreadCount: 0
    property bool autoSyncEnabled: preferences.autoSyncEnabled
    property bool syncOnStartup: preferences.syncOnStartup
    property int syncIntervalMinutes: preferences.syncIntervalMinutes
    property bool sortOldestFirst: preferences.sortOldestFirst
    property string searchIn: preferences.searchIn
    property bool openInBrowserDirectly: preferences.openInBrowserDirectly
    property bool markReadWhileScrolling: false

    property alias folders: foldersModel
    property alias feeds: feedsModel
    property alias navigation: navigationModel
    property alias model: itemsModel

    property var allFolders: []
    property var allFeeds: []
    property var allItems: []
    property var pendingOperations: []
    property var pendingManagementOperations: []
    property var currentManagementOperation: null
    property bool processingQueuedManagement: false
    property bool localStateUploadOnly: false
    property string createFolderRequestedName: ""
    property string runtimeUserName: ""
    property string runtimeSecret: ""
    property string activeAccountKey: ""
    property int feedDeleteInProgressId: 0
    property int folderDeleteInProgressId: 0
    property var folderDeleteFeedIds: []
    property int accountRequestGeneration: 0

    signal itemOpened(int itemId)
    signal folderAvailable(int folderId, string name)

    ListModel {
        id: foldersModel
    }

    ListModel {
        id: feedsModel
    }

    ListModel {
        id: navigationModel
    }

    ListModel {
        id: itemsModel
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

    Settings {
        id: preferences
        category: "preferences"
        property bool autoSyncEnabled: true
        property bool syncOnStartup: true
        property int syncIntervalMinutes: 15
        property bool sortOldestFirst: false
        property string searchIn: "both"
        property bool openInBrowserDirectly: false
        property bool markReadWhileScrolling: false
    }

    NewsCache {
        id: cache
    }

    AccountSessionAdapter {
        id: accountSession

        onAuthenticated: function(userName, secret, serverUrl, accountId, serviceId) {
            if (!controller.isCurrentAccountResponse(accountId, serviceId, serverUrl)) {
                return
            }
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            if (serverUrl && serverUrl.length > 0) {
                accountSettings.serverUrl = serverUrl
            }
            controller.accountAvatarUrl = controller.avatarUrl(accountSettings.serverUrl, userName)
            accountSettings.avatarUrl = controller.accountAvatarUrl
        }

        onFailed: {
            controller.loading = false
            controller.syncRunning = false
            controller.localStateUploadOnly = false
            controller.createFolderRequestedName = ""
            controller.folderCreateRunning = false
            controller.feedCreateRunning = false
            controller.statusText = message
            controller.syncStateText = i18n.tr("Authentication failed")
            controller.syncStateColor = "#b33a3a"
        }
    }

    NewsApiClient {
        id: api

        onFoldersLoaded: function(folders, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            cache.saveFolders(folders)
            controller.allFolders = folders
            controller.rebuildFolderFeedModels()
            controller.rebuildNavigation()
            controller.emitRequestedFolderIfAvailable(folders)
            api.fetchFeeds(accountSettings.serverUrl, controller.runtimeUserName, controller.runtimeSecret)
        }

        onFolderCreated: function(folders, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.folderCreateRunning = false
            if (folders && folders.length > 0) {
                cache.saveFolders(folders)
                controller.allFolders = folders
                controller.rebuildFolderFeedModels()
                controller.rebuildNavigation()
                controller.emitRequestedFolderIfAvailable(folders)
            }
            controller.statusText = i18n.tr("Folder added. Refreshing...")
            controller.syncStateText = i18n.tr("Syncing")
            controller.syncStateColor = "#2c7fb8"
            api.fetchFolders(accountSettings.serverUrl, controller.runtimeUserName, controller.runtimeSecret)
        }

        onFolderRenamed: function(folderId, name, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.finishManagementOperation()
            cache.renameFolder(folderId, name)
            controller.statusText = i18n.tr("Folder renamed. Refreshing...")
            controller.syncStateText = i18n.tr("Syncing")
            controller.syncStateColor = "#2c7fb8"
            controller.loadCached()
            api.fetchFolders(accountSettings.serverUrl, controller.runtimeUserName, controller.runtimeSecret)
        }

        onFeedsLoaded: function(feeds, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            cache.saveFeeds(feeds)
            controller.allFeeds = feeds
            controller.rebuildFolderFeedModels()
            controller.rebuildNavigation()
            controller.fetchItemsFromServer()
        }

        onFeedCreated: function(generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.feedCreateRunning = false
            controller.statusText = i18n.tr("Feed added. Refreshing...")
            controller.syncStateText = i18n.tr("Syncing")
            controller.syncStateColor = "#2c7fb8"
            api.fetchFolders(accountSettings.serverUrl, controller.runtimeUserName, controller.runtimeSecret)
        }

        onFeedRenamed: function(feedId, title, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.finishManagementOperation()
            cache.renameFeed(feedId, title)
            controller.statusText = i18n.tr("Feed renamed. Refreshing...")
            controller.syncStateText = i18n.tr("Syncing")
            controller.syncStateColor = "#2c7fb8"
            controller.loadCached()
            api.fetchFolders(accountSettings.serverUrl, controller.runtimeUserName, controller.runtimeSecret)
        }

        onFeedMoved: function(generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.finishManagementOperation()
            controller.statusText = i18n.tr("Feed moved. Refreshing...")
            controller.syncStateText = i18n.tr("Syncing")
            controller.syncStateColor = "#2c7fb8"
            api.fetchFolders(accountSettings.serverUrl, controller.runtimeUserName, controller.runtimeSecret)
        }

        onFeedDeleted: function(feedId, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var deletedFeedId = feedId > 0 ? feedId : feedDeleteInProgressId
            cache.removeFeed(deletedFeedId)
            if (folderDeleteInProgressId > 0) {
                controller.deleteNextFeedInFolder()
                return
            }
            controller.finishManagementOperation()
            controller.statusText = i18n.tr("Feed deleted. Refreshing...")
            controller.syncStateText = i18n.tr("Syncing")
            controller.syncStateColor = "#2c7fb8"
            feedDeleteInProgressId = 0
            controller.clearDeletedFilter("feed", deletedFeedId)
            controller.loadCached()
            api.fetchFolders(accountSettings.serverUrl, controller.runtimeUserName, controller.runtimeSecret)
        }

        onFolderDeleted: function(folderId, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.finishManagementOperation()
            cache.removeFolder(folderId)
            controller.statusText = i18n.tr("Folder deleted. Refreshing...")
            controller.syncStateText = i18n.tr("Syncing")
            controller.syncStateColor = "#2c7fb8"
            controller.clearDeletedFilter("folder", folderId)
            folderDeleteInProgressId = 0
            folderDeleteFeedIds = []
            controller.loadCached()
            api.fetchFolders(accountSettings.serverUrl, controller.runtimeUserName, controller.runtimeSecret)
        }

        onItemsLoaded: function(items, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            cache.saveItems(items)
            controller.loadCached()
            controller.loading = false
            controller.statusText = i18n.tr("Articles refreshed.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
        }

        onItemStateUploaded: function(itemId, unread, starred, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            cache.clearPending(itemId)
            controller.clearPendingInModels(itemId)
            controller.processNextPending()
        }

        onItemStatesUploaded: function(itemIds, unread, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            for (var i = 0; i < itemIds.length; ++i) {
                cache.clearPending(itemIds[i])
                controller.clearPendingInModels(itemIds[i])
            }
            controller.processNextPending()
        }

        onFailed: function(message, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var queuedManagement = controller.queueCurrentManagementOperation()
            controller.loading = false
            controller.syncRunning = false
            controller.localStateUploadOnly = false
            controller.createFolderRequestedName = ""
            controller.folderCreateRunning = false
            controller.feedCreateRunning = false
            if (!queuedManagement) {
                controller.statusText = message
            }
            controller.syncStateText = controller.hasCachedItems ? i18n.tr("Offline cache") : i18n.tr("Sync failed")
            controller.syncStateColor = "#b37a2a"
            controller.loadCached()
        }
    }

    Timer {
        id: activeRefreshTimer
        interval: Math.max(1, controller.syncIntervalMinutes) * 60000
        repeat: true
        running: Qt.application.active && controller.autoSyncEnabled
        onTriggered: controller.loadNews()
    }

    Timer {
        id: localStateUploadTimer
        interval: 1200
        repeat: false
        onTriggered: controller.uploadLocalStateOnly()
    }

    Timer {
        id: accountRefreshTimer
        interval: 150
        repeat: false
        onTriggered: controller.loadNews()
    }

    Component.onCompleted: {
        if (preferences.markReadWhileScrolling) {
            preferences.markReadWhileScrolling = false
        }
        markReadWhileScrolling = false
        activeAccountKey = accountKey()
        accountSession.setAccount(accountSettings.accountId, accountSettings.providerId, accountSettings.serviceId, accountSettings.serverUrl)
        accountAvatarUrl = accountSettings.avatarUrl || ""
        loadCached()
        if (syncOnStartup) {
            loadNews()
        }
    }

    function handleApplicationActivated() {
        if (autoSyncEnabled) {
            activeRefreshTimer.restart()
            loadNews()
        }
    }

    function handleApplicationDeactivated() {
        activeRefreshTimer.stop()
        if (cache.loadPendingItems().length > 0 && accountReady() && !syncRunning) {
            localStateUploadTimer.stop()
            uploadLocalStateOnly()
        }
    }

    function loadCached() {
        allFolders = cache.loadFolders()
        allFeeds = cache.loadFeeds()
        allItems = cache.loadItems()
        hasCachedItems = allItems.length > 0
        refreshPendingCount(false)
        rebuildFolderFeedModels()
        rebuildNavigation()
        rebuildModel()
    }

    function refreshPendingCount(normalizeIdleStatus) {
        pendingCount = cache.loadPendingItems().length + cache.loadPendingManagementOperations().length
        if (normalizeIdleStatus === true && pendingCount === 0 && !loading && !syncRunning) {
            syncStateText = i18n.tr("Up to date")
            syncStateColor = "#5a8f3c"
        }
    }

    function loadNews() {
        accountSession.setAccount(accountSettings.accountId, accountSettings.providerId, accountSettings.serviceId, accountSettings.serverUrl)
        api.requestGeneration = accountRequestGeneration
        loadCached()
        if (!accountReady()) {
            statusText = i18n.tr("Add a Nextcloud or ownCloud account in System Settings > Accounts, then authorize it here.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return
        }
        loading = true
        statusText = hasCachedItems ? i18n.tr("Showing cached articles. Refreshing...") : i18n.tr("Loading articles...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        accountSession.withCredentials(function(userName, secret, serverUrl, accountId, serviceId) {
            if (!controller.isCurrentAccountResponse(accountId, serviceId, serverUrl)) {
                return
            }
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            syncPendingThenPull()
        })
    }

    function applyAccountSelection(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl) {
        accountRequestGeneration += 1
        stopAccountActivity()
        accountSettings.accountId = accountId
        accountSettings.displayName = displayName || ""
        accountSettings.providerId = providerId || ""
        accountSettings.serviceId = serviceId || ""
        accountSettings.serverUrl = serverUrl || ""
        accountSettings.avatarUrl = avatarUrl || ""
        accountSession.setAccount(accountSettings.accountId, accountSettings.providerId, accountSettings.serviceId, accountSettings.serverUrl)
        clearAccountData()
        activeAccountKey = accountKey()
        accountRefreshTimer.restart()
    }

    function stopAccountActivity() {
        localStateUploadTimer.stop()
        accountRefreshTimer.stop()
        loading = false
        syncRunning = false
        folderCreateRunning = false
        feedCreateRunning = false
        localStateUploadOnly = false
        createFolderRequestedName = ""
        runtimeUserName = ""
        runtimeSecret = ""
        pendingOperations = []
        pendingManagementOperations = []
        currentManagementOperation = null
        processingQueuedManagement = false
        feedDeleteInProgressId = 0
        folderDeleteInProgressId = 0
        folderDeleteFeedIds = []
        accountSession.setAccount(accountSettings.accountId, accountSettings.providerId, accountSettings.serviceId, accountSettings.serverUrl)
        api.requestGeneration = accountRequestGeneration
    }

    function clearAccountData() {
        foldersModel.clear()
        feedsModel.clear()
        navigationModel.clear()
        itemsModel.clear()
        allFolders = []
        allFeeds = []
        allItems = []
        hasCachedItems = false
        pendingCount = 0
        accountAvatarUrl = accountSettings.avatarUrl || ""
        loading = false
        syncRunning = false
        statusText = accountSettings.accountId > 0
            ? i18n.tr("Account changed. Refreshing...")
            : i18n.tr("Add a Nextcloud or ownCloud account in System Settings > Accounts, then authorize it here.")
    }

    function accountKey() {
        return String(accountSettings.accountId)
            + "|" + String(accountSettings.providerId || "")
            + "|" + String(accountSettings.serviceId || "")
            + "|" + String(accountSettings.serverUrl || "")
    }

    function isCurrentAccountResponse(accountId, serviceId, serverUrl) {
        if (typeof desktopTestAuthEnabled !== "undefined" && desktopTestAuthEnabled
                && Number(accountId || 0) === -1
                && String(serviceId || "") === "desktop-test-env") {
            return true
        }
        return Number(accountId || 0) === Number(accountSettings.accountId || 0)
            && String(serviceId || "") === String(accountSettings.serviceId || "")
            && String(serverUrl || "").replace(/\/+$/, "") === String(accountSettings.serverUrl || "").replace(/\/+$/, "")
    }

    function isCurrentApiGeneration(generation) {
        return Number(generation || 0) === Number(accountRequestGeneration || 0)
    }

    function syncPendingThenPull() {
        pendingOperations = SyncPlanner.planPendingItems(cache.loadPendingItems())
        pendingManagementOperations = cache.loadPendingManagementOperations()
        pendingCount = pendingOperations.length + pendingManagementOperations.length
        if (pendingManagementOperations.length > 0) {
            syncRunning = true
            processNextManagementOperation()
        } else if (pendingOperations.length > 0) {
            syncRunning = true
            processNextPending()
        } else {
            syncRunning = false
            api.fetchFolders(accountSettings.serverUrl, runtimeUserName, runtimeSecret)
        }
    }

    function processNextManagementOperation() {
        pendingManagementOperations = cache.loadPendingManagementOperations()
        if (pendingManagementOperations.length === 0) {
            processingQueuedManagement = false
            currentManagementOperation = null
            processNextPending()
            return
        }

        var operation = pendingManagementOperations[0]
        currentManagementOperation = operation
        processingQueuedManagement = true
        syncStateText = i18n.tr("Uploading subscription changes")

        if (operation.kind === "renameFeed") {
            api.renameFeed(accountSettings.serverUrl, runtimeUserName, runtimeSecret, operation.targetId, operation.payload.title || "")
        } else if (operation.kind === "renameFolder") {
            api.renameFolder(accountSettings.serverUrl, runtimeUserName, runtimeSecret, operation.targetId, operation.payload.name || "")
        } else if (operation.kind === "moveFeed") {
            api.moveFeed(accountSettings.serverUrl, runtimeUserName, runtimeSecret, operation.targetId, operation.payload.folderId || 0)
        } else if (operation.kind === "deleteFeed") {
            feedDeleteInProgressId = operation.targetId
            api.deleteFeed(accountSettings.serverUrl, runtimeUserName, runtimeSecret, operation.targetId)
        } else if (operation.kind === "deleteFolder") {
            folderDeleteInProgressId = operation.targetId
            folderDeleteFeedIds = feedIdsForFolder(operation.targetId)
            deleteNextFeedInFolder()
        } else {
            cache.removePendingManagementOperation(operation.operationId)
            processNextManagementOperation()
        }
    }

    function finishManagementOperation() {
        if (processingQueuedManagement && currentManagementOperation && currentManagementOperation.operationId > 0) {
            cache.removePendingManagementOperation(currentManagementOperation.operationId)
        }
        currentManagementOperation = null
        processingQueuedManagement = false
    }

    function queueCurrentManagementOperation() {
        if (!currentManagementOperation || processingQueuedManagement) {
            return false
        }
        cache.queueManagementOperation(
            currentManagementOperation.kind,
            currentManagementOperation.targetId,
            currentManagementOperation.payload
        )
        currentManagementOperation = null
        statusText = i18n.tr("Subscription change saved and will retry on next sync.")
        return true
    }

    function processNextPending() {
        pendingOperations = SyncPlanner.planPendingItems(cache.loadPendingItems())
        pendingCount = pendingOperations.length + cache.loadPendingManagementOperations().length
        if (pendingOperations.length === 0) {
            syncRunning = false
            if (localStateUploadOnly) {
                localStateUploadOnly = false
                statusText = i18n.tr("Local article changes uploaded.")
                syncStateText = i18n.tr("Up to date")
                syncStateColor = "#5a8f3c"
            } else {
                api.fetchFolders(accountSettings.serverUrl, runtimeUserName, runtimeSecret)
            }
            return
        }

        var operation = pendingOperations[0]
        var item = operation.item
        syncStateText = i18n.tr("Uploading local changes")
        if (operation.kind === "state") {
            api.markItemRead(accountSettings.serverUrl, runtimeUserName, runtimeSecret, item.itemId, !item.unread)
        } else if (operation.kind === "star") {
            api.starItem(accountSettings.serverUrl, runtimeUserName, runtimeSecret, item, item.starred)
        }
    }

    function fetchItemsFromServer() {
        var type = 3
        var id = 0
        if (selectedFilterType === "feed") {
            type = 0
            id = selectedFilterId
        } else if (selectedFilterType === "folder") {
            type = 1
            id = selectedFilterId
        } else if (selectedFilterType === "starred") {
            type = 2
        }
        api.fetchItems(accountSettings.serverUrl, runtimeUserName, runtimeSecret, type, id, true)
    }

    function setSearchQuery(value) {
        searchQuery = value || ""
        rebuildModel()
    }

    function clearSearch() {
        searchQuery = ""
        rebuildModel()
    }

    function selectFilter(type, id, label) {
        selectedFilterType = type
        selectedFilterId = Number(id || 0)
        selectedFilterLabel = label || i18n.tr("All articles")
        rebuildModel()
        loadNews()
    }

    function setAutoSyncEnabled(value) {
        preferences.autoSyncEnabled = value
        autoSyncEnabled = value
        if (value && Qt.application.active) {
            activeRefreshTimer.restart()
        } else {
            activeRefreshTimer.stop()
        }
    }

    function setSyncOnStartup(value) {
        preferences.syncOnStartup = value
        syncOnStartup = value
    }

    function setSyncIntervalMinutes(value) {
        var minutes = Math.max(1, Number(value || 1))
        preferences.syncIntervalMinutes = minutes
        syncIntervalMinutes = minutes
        if (autoSyncEnabled && Qt.application.active) {
            activeRefreshTimer.restart()
        }
    }

    function setSortOldestFirst(value) {
        preferences.sortOldestFirst = value
        sortOldestFirst = value
        rebuildModel()
    }

    function setSearchIn(value) {
        var mode = String(value || "both")
        if (mode !== "title" && mode !== "body") {
            mode = "both"
        }
        preferences.searchIn = mode
        searchIn = mode
        rebuildModel()
    }

    function setOpenInBrowserDirectly(value) {
        preferences.openInBrowserDirectly = value
        openInBrowserDirectly = value
    }

    function setMarkReadWhileScrolling(value) {
        preferences.markReadWhileScrolling = false
        markReadWhileScrolling = false
    }

    function setFeedOpenExternal(feedId, value) {
        cache.setFeedOpenExternal(feedId, value)
        loadCached()
    }

    function feedOpenExternal(feedId) {
        for (var i = 0; i < allFeeds.length; ++i) {
            if (Number(allFeeds[i].feedId) === Number(feedId)) {
                return allFeeds[i].openExternal === true
            }
        }
        return false
    }

    function shouldOpenItemExternally(item) {
        if (!item || !item.url || item.url.length === 0) {
            return false
        }
        return openInBrowserDirectly || feedOpenExternal(item.feedId)
    }

    function openItem(itemId) {
        var item = getItem(itemId)
        if (!item) {
            return "missing"
        }
        itemOpened(itemId)
        if (shouldOpenItemExternally(item)) {
            Qt.openUrlExternally(item.url)
            if (item.unread) {
                markRead(itemId, true)
            }
            return "external"
        }
        return "detail"
    }

    function markReadFromScroll(itemId) {
        if (!markReadWhileScrolling) {
            return
        }
        var item = getItem(itemId)
        if (item && item.unread) {
            markRead(itemId, true, true)
        }
    }

    function getItem(itemId) {
        for (var i = 0; i < allItems.length; ++i) {
            if (Number(allItems[i].itemId) === Number(itemId)) {
                return allItems[i]
            }
        }
        return null
    }

    function markRead(itemId, read, deferUpload) {
        var unread = !read
        cache.updateLocalReadState(itemId, unread, true)
        updateLocalReadStateInModels(itemId, unread, true)
        if (accountReady()) {
            if (deferUpload === true) {
                scheduleLocalStateUpload()
            } else {
                scheduleLocalStateUpload()
            }
        }
    }

    function toggleRead(itemId) {
        var item = getItem(itemId)
        if (!item) {
            return
        }
        markRead(itemId, item.unread, true)
    }

    function markVisibleRead() {
        var ids = []
        for (var i = 0; i < model.count; ++i) {
            var row = model.get(i)
            if (row.unread) {
                ids.push(row.itemId)
            }
        }
        if (ids.length === 0) {
            statusText = i18n.tr("No unread articles in this view.")
            syncStateText = i18n.tr("Up to date")
            syncStateColor = "#5a8f3c"
            return 0
        }
        cache.updateLocalReadStates(ids, false, true)
        updateLocalReadStatesInModels(ids, false, true)
        statusText = ids.length === 1
            ? i18n.tr("Marked 1 article as read.")
            : i18n.tr("Marked %1 articles as read.").arg(ids.length)
        syncStateText = i18n.tr("Uploading local changes")
        syncStateColor = "#2c7fb8"
        loadCached()
        if (accountReady()) {
            uploadReadStatesNow(ids, true)
        }
        return ids.length
    }

    function toggleStar(itemId) {
        var item = getItem(itemId)
        if (!item) {
            return
        }
        cache.updateLocalStarState(itemId, !item.starred, true)
        updateLocalStarStateInModels(itemId, !item.starred, true)
        if (accountReady()) {
            scheduleLocalStateUpload()
        }
    }

    function updateLocalReadStatesInModels(itemIds, unread, pending) {
        for (var i = 0; i < itemIds.length; ++i) {
            updateLocalReadStateInModels(itemIds[i], unread, pending)
        }
    }

    function updateLocalReadStateInModels(itemId, unread, pending) {
        for (var i = 0; i < allItems.length; ++i) {
            if (Number(allItems[i].itemId) === Number(itemId)) {
                allItems[i].unread = unread
                allItems[i].pendingState = pending ? "state" : ""
                break
            }
        }
        for (var row = 0; row < model.count; ++row) {
            if (Number(model.get(row).itemId) === Number(itemId)) {
                model.setProperty(row, "unread", unread)
                model.setProperty(row, "pendingState", pending ? "state" : "")
                break
            }
        }
        pendingCount = cache.loadPendingItems().length + cache.loadPendingManagementOperations().length
        visibleUnreadCount = countVisibleUnread()
        rebuildNavigation()
    }

    function updateLocalStarStateInModels(itemId, starred, pending) {
        for (var i = 0; i < allItems.length; ++i) {
            if (Number(allItems[i].itemId) === Number(itemId)) {
                allItems[i].starred = starred
                allItems[i].pendingState = pending ? "star" : ""
                break
            }
        }
        for (var row = 0; row < model.count; ++row) {
            if (Number(model.get(row).itemId) === Number(itemId)) {
                model.setProperty(row, "starred", starred)
                model.setProperty(row, "pendingState", pending ? "star" : "")
                break
            }
        }
        pendingCount = cache.loadPendingItems().length + cache.loadPendingManagementOperations().length
        rebuildNavigation()
    }

    function clearPendingInModels(itemId) {
        for (var i = 0; i < allItems.length; ++i) {
            if (Number(allItems[i].itemId) === Number(itemId)) {
                allItems[i].pendingState = ""
                break
            }
        }
        for (var row = 0; row < model.count; ++row) {
            if (Number(model.get(row).itemId) === Number(itemId)) {
                model.setProperty(row, "pendingState", "")
                break
            }
        }
        refreshPendingCount(true)
    }

    function pendingChangeRows() {
        var rows = []
        var pendingItems = cache.loadPendingItems()
        for (var i = 0; i < pendingItems.length; ++i) {
            var item = pendingItems[i]
            rows.push({
                "kind": item.pendingState === "star" ? i18n.tr("Star change") : i18n.tr("Read state change"),
                "title": item.title || i18n.tr("Untitled article"),
                "detail": item.pendingState === "star"
                    ? (item.starred ? i18n.tr("Will be starred on the server.") : i18n.tr("Will be unstarred on the server."))
                    : (item.unread ? i18n.tr("Will be marked unread on the server.") : i18n.tr("Will be marked read on the server."))
            })
        }

        var pendingManagement = cache.loadPendingManagementOperations()
        for (var m = 0; m < pendingManagement.length; ++m) {
            var operation = pendingManagement[m]
            rows.push({
                "kind": i18n.tr("Subscription change"),
                "title": operation.kind || i18n.tr("Queued operation"),
                "detail": i18n.tr("Will retry on the next sync.")
            })
        }
        return rows
    }

    function retryPendingChanges() {
        if (!accountReady()) {
            statusText = i18n.tr("Authorize a Nextcloud account before retrying sync.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return false
        }
        statusText = i18n.tr("Retrying local changes...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        loadNews()
        return true
    }

    function discardPendingChangesAndRefresh() {
        cache.clearAllPendingItems()
        cache.clearPendingManagementOperations()
        loadCached()
        statusText = i18n.tr("Local pending changes discarded. Refreshing...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        if (accountReady()) {
            loadNews()
        } else {
            statusText = i18n.tr("Local pending changes discarded.")
            refreshPendingCount(true)
        }
    }

    function countVisibleUnread() {
        var unread = 0
        for (var i = 0; i < model.count; ++i) {
            if (model.get(i).unread) {
                unread += 1
            }
        }
        return unread
    }

    function scheduleLocalStateUpload() {
        statusText = i18n.tr("Local article change saved.")
        syncStateText = i18n.tr("Uploading local changes")
        syncStateColor = "#2c7fb8"
        localStateUploadTimer.restart()
    }

    function uploadLocalStateOnly() {
        if (!accountReady()) {
            return
        }
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            controller.localStateUploadOnly = true
            controller.syncRunning = true
            controller.processNextPending()
        })
    }

    function uploadReadStatesNow(itemIds, read) {
        if (!accountReady() || !itemIds || itemIds.length === 0) {
            return
        }
        localStateUploadTimer.stop()
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            controller.localStateUploadOnly = true
            controller.syncRunning = true
            controller.syncStateText = i18n.tr("Uploading local changes")
            controller.syncStateColor = "#2c7fb8"
            api.markItemsRead(accountSettings.serverUrl, userName, secret, itemIds, read)
        })
    }

    function createFeed(feedUrl, folderId) {
        var url = String(feedUrl || "").trim()
        if (url.length === 0) {
            statusText = i18n.tr("Enter a feed URL.")
            syncStateText = i18n.tr("Feed not added")
            syncStateColor = "#b37a2a"
            return false
        }
        if (url.indexOf("http://") !== 0 && url.indexOf("https://") !== 0) {
            url = "https://" + url
        }
        if (!accountReady()) {
            statusText = i18n.tr("Authorize a Nextcloud account before adding feeds.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return false
        }

        loading = true
        feedCreateRunning = true
        statusText = i18n.tr("Adding feed...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            api.createFeed(accountSettings.serverUrl, userName, secret, url, folderId || 0)
        })
        return true
    }

    function createFolder(name) {
        var folderName = String(name || "").trim()
        if (folderName.length === 0) {
            statusText = i18n.tr("Enter a folder name.")
            syncStateText = i18n.tr("Folder not added")
            syncStateColor = "#b37a2a"
            return false
        }
        if (!accountReady()) {
            statusText = i18n.tr("Authorize a Nextcloud account before adding folders.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return false
        }

        loading = true
        folderCreateRunning = true
        statusText = i18n.tr("Adding folder...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            createFolderRequestedName = folderName
            api.createFolder(accountSettings.serverUrl, userName, secret, folderName)
        })
        return true
    }

    function emitRequestedFolderIfAvailable(folders) {
        if (createFolderRequestedName.length === 0) {
            return
        }
        for (var i = 0; i < folders.length; ++i) {
            if (String(folders[i].name || "") === createFolderRequestedName) {
                folderAvailable(Number(folders[i].folderId || 0), createFolderRequestedName)
                createFolderRequestedName = ""
                return
            }
        }
    }

    function renameFeed(feedId, title) {
        var feedTitle = String(title || "").trim()
        if (feedTitle.length === 0) {
            statusText = i18n.tr("Enter a feed name.")
            syncStateText = i18n.tr("Feed not renamed")
            syncStateColor = "#b37a2a"
            return false
        }
        if (!accountReady()) {
            statusText = i18n.tr("Authorize a Nextcloud account before renaming feeds.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return false
        }

        loading = true
        statusText = i18n.tr("Renaming feed...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            currentManagementOperation = { "kind": "renameFeed", "targetId": Number(feedId || 0), "payload": { "title": feedTitle } }
            api.renameFeed(accountSettings.serverUrl, userName, secret, feedId, feedTitle)
        })
        return true
    }

    function renameFolder(folderId, name) {
        var folderName = String(name || "").trim()
        if (folderName.length === 0) {
            statusText = i18n.tr("Enter a folder name.")
            syncStateText = i18n.tr("Folder not renamed")
            syncStateColor = "#b37a2a"
            return false
        }
        if (!accountReady()) {
            statusText = i18n.tr("Authorize a Nextcloud account before renaming folders.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return false
        }

        loading = true
        statusText = i18n.tr("Renaming folder...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            currentManagementOperation = { "kind": "renameFolder", "targetId": Number(folderId || 0), "payload": { "name": folderName } }
            api.renameFolder(accountSettings.serverUrl, userName, secret, folderId, folderName)
        })
        return true
    }

    function moveFeed(feedId, folderId) {
        if (!accountReady()) {
            statusText = i18n.tr("Authorize a Nextcloud account before moving feeds.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return false
        }
        loading = true
        statusText = i18n.tr("Moving feed...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            currentManagementOperation = { "kind": "moveFeed", "targetId": Number(feedId || 0), "payload": { "folderId": Number(folderId || 0) } }
            api.moveFeed(accountSettings.serverUrl, userName, secret, feedId, folderId)
        })
        return true
    }

    function deleteFeed(feedId) {
        if (!accountReady()) {
            statusText = i18n.tr("Authorize a Nextcloud account before deleting feeds.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return false
        }
        loading = true
        statusText = i18n.tr("Deleting feed...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            feedDeleteInProgressId = Number(feedId || 0)
            currentManagementOperation = { "kind": "deleteFeed", "targetId": Number(feedId || 0), "payload": {} }
            api.deleteFeed(accountSettings.serverUrl, userName, secret, feedId)
        })
        return true
    }

    function deleteFolder(folderId) {
        if (!accountReady()) {
            statusText = i18n.tr("Authorize a Nextcloud account before deleting folders.")
            syncStateText = i18n.tr("No account")
            syncStateColor = "#b37a2a"
            return false
        }

        var feedIds = feedIdsForFolder(folderId)

        loading = true
        statusText = feedIds.length > 0
            ? i18n.tr("Deleting folder feeds...")
            : i18n.tr("Deleting folder...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        accountSession.withCredentials(function(userName, secret) {
            controller.runtimeUserName = userName
            controller.runtimeSecret = secret
            folderDeleteInProgressId = Number(folderId || 0)
            folderDeleteFeedIds = feedIds
            currentManagementOperation = { "kind": "deleteFolder", "targetId": Number(folderId || 0), "payload": {} }
            controller.deleteNextFeedInFolder()
        })
        return true
    }

    function feedIdsForFolder(folderId) {
        var feedIds = []
        for (var i = 0; i < allFeeds.length; ++i) {
            if (Number(allFeeds[i].folderId) === Number(folderId)) {
                feedIds.push(Number(allFeeds[i].feedId))
            }
        }
        return feedIds
    }

    function deleteNextFeedInFolder() {
        if (folderDeleteFeedIds.length > 0) {
            var feedId = folderDeleteFeedIds.shift()
            feedDeleteInProgressId = feedId
            statusText = i18n.tr("Deleting folder feeds...")
            api.deleteFeed(accountSettings.serverUrl, runtimeUserName, runtimeSecret, feedId)
            return
        }
        api.deleteFolder(accountSettings.serverUrl, runtimeUserName, runtimeSecret, folderDeleteInProgressId)
    }

    function clearDeletedFilter(type, id) {
        if (selectedFilterType === type && Number(selectedFilterId) === Number(id)) {
            selectedFilterType = "all"
            selectedFilterId = 0
            selectedFilterLabel = i18n.tr("All articles")
        }
    }

    function rebuildFolderFeedModels() {
        foldersModel.clear()
        for (var f = 0; f < allFolders.length; ++f) {
            foldersModel.append({ "folderId": allFolders[f].folderId, "name": allFolders[f].name })
        }
        feedsModel.clear()
        for (var i = 0; i < allFeeds.length; ++i) {
            feedsModel.append({
                "feedId": allFeeds[i].feedId,
                "folderId": allFeeds[i].folderId,
                "title": allFeeds[i].title,
                "url": allFeeds[i].url,
                "faviconLink": allFeeds[i].faviconLink,
                "unreadCount": allFeeds[i].unreadCount,
                "openExternal": allFeeds[i].openExternal
            })
        }
    }

    function rebuildNavigation() {
        navigation.clear()
        navigation.append({ "type": "all", "id": 0, "label": i18n.tr("All articles"), "count": countItems("all", 0), "groupLabel": i18n.tr("Views") })
        navigation.append({ "type": "unread", "id": 0, "label": i18n.tr("Unread"), "count": countItems("unread", 0), "groupLabel": i18n.tr("Views") })
        navigation.append({ "type": "starred", "id": 0, "label": i18n.tr("Starred"), "count": countItems("starred", 0), "groupLabel": i18n.tr("Views") })
        for (var f = 0; f < allFolders.length; ++f) {
            navigation.append({ "type": "folder", "id": allFolders[f].folderId, "label": allFolders[f].name, "count": countItems("folder", allFolders[f].folderId), "groupLabel": i18n.tr("Folders") })
        }
        for (var i = 0; i < allFeeds.length; ++i) {
            navigation.append({ "type": "feed", "id": allFeeds[i].feedId, "label": allFeeds[i].title, "count": countItems("feed", allFeeds[i].feedId), "groupLabel": i18n.tr("Feeds") })
        }
    }

    function rebuildModel() {
        model.clear()
        var query = searchQuery.toLowerCase()
        var unread = 0
        var sortedItems = allItems.slice(0)
        sortedItems.sort(function(a, b) {
            var left = Number(a.pubDate || 0)
            var right = Number(b.pubDate || 0)
            if (left === right) {
                var leftId = Number(a.itemId || 0)
                var rightId = Number(b.itemId || 0)
                return sortOldestFirst ? leftId - rightId : rightId - leftId
            }
            return sortOldestFirst ? left - right : right - left
        })
        for (var i = 0; i < sortedItems.length; ++i) {
            var item = sortedItems[i]
            if (!matchesFilter(item) || !matchesSearch(item, query)) {
                continue
            }
            if (item.unread) {
                unread += 1
            }
            var feed = feedForId(item.feedId)
            item.feedTitle = feed.title || ""
            item.feedFaviconLink = feed.faviconLink || ""
            item.sectionKey = sectionKeyForTimestamp(item.pubDate)
            item.sectionLabel = sectionLabelForTimestamp(item.pubDate)
            model.append(item)
        }
        visibleUnreadCount = unread
    }

    function feedForId(feedId) {
        for (var i = 0; i < allFeeds.length; ++i) {
            if (Number(allFeeds[i].feedId) === Number(feedId)) {
                return allFeeds[i]
            }
        }
        return {}
    }

    function sectionKeyForTimestamp(seconds) {
        var label = sectionLabelForTimestamp(seconds)
        if (!seconds || seconds <= 0) {
            return (sortOldestFirst ? "00000000" : "99999999") + "|" + label
        }
        var articleDate = new Date(Number(seconds) * 1000)
        var year = articleDate.getFullYear()
        var month = articleDate.getMonth() + 1
        var day = articleDate.getDate()
        var keyNumber = year * 10000 + month * 100 + day
        var key = sortOldestFirst
            ? keyNumber
            : 99999999 - keyNumber
        return String(key) + "|" + label
    }

    function sectionLabelForTimestamp(seconds) {
        if (!seconds || seconds <= 0) {
            return i18n.tr("Older")
        }
        var articleDate = new Date(Number(seconds) * 1000)
        var today = new Date()
        var startToday = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        var startYesterday = new Date(startToday.getTime() - 24 * 60 * 60 * 1000)
        if (articleDate >= startToday) {
            return i18n.tr("Today")
        }
        if (articleDate >= startYesterday) {
            return i18n.tr("Yesterday")
        }
        return Qt.formatDate(articleDate, "d MMM")
    }

    function matchesFilter(item) {
        if (selectedFilterType === "all") {
            return true
        }
        if (selectedFilterType === "unread") {
            return item.unread
        }
        if (selectedFilterType === "starred") {
            return item.starred
        }
        if (selectedFilterType === "feed") {
            return Number(item.feedId) === Number(selectedFilterId)
        }
        if (selectedFilterType === "folder") {
            for (var i = 0; i < allFeeds.length; ++i) {
                if (Number(allFeeds[i].feedId) === Number(item.feedId)) {
                    return Number(allFeeds[i].folderId) === Number(selectedFilterId)
                }
            }
        }
        return true
    }

    function matchesSearch(item, query) {
        if (query.length === 0) {
            return true
        }
        var titleMatch = String(item.title || "").toLowerCase().indexOf(query) >= 0
            || String(item.author || "").toLowerCase().indexOf(query) >= 0
        var bodyMatch = String(item.preview || "").toLowerCase().indexOf(query) >= 0
        if (searchIn === "title") {
            return titleMatch
        }
        if (searchIn === "body") {
            return bodyMatch
        }
        return titleMatch || bodyMatch
    }

    function countItems(type, id) {
        var count = 0
        for (var i = 0; i < allItems.length; ++i) {
            if (matchesFilterType(allItems[i], type, id) && allItems[i].unread) {
                count += 1
            }
        }
        return count
    }

    function matchesFilterType(item, type, id) {
        if (type === "all") {
            return true
        }
        if (type === "unread") {
            return item.unread
        }
        if (type === "starred") {
            return item.starred
        }
        if (type === "feed") {
            return Number(item.feedId) === Number(id)
        }
        if (type === "folder") {
            for (var i = 0; i < allFeeds.length; ++i) {
                if (Number(allFeeds[i].feedId) === Number(item.feedId)) {
                    return Number(allFeeds[i].folderId) === Number(id)
                }
            }
        }
        return true
    }

    function accountReady() {
        if (accountSession.envTestAuthEnabled) {
            return true
        }
        return accountSettings.accountId > 0
            && accountSettings.serviceId.length > 0
            && accountSettings.serverUrl.length > 0
    }

    function avatarUrl(serverUrl, userName) {
        if (!serverUrl || !userName) {
            return ""
        }
        return String(serverUrl).replace(/\/+$/, "") + "/index.php/avatar/" + encodeURIComponent(userName) + "/64"
    }
}
