import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtGraphicalEffects 1.0
import Qt.labs.settings 1.0

Page {
    id: page

    property var newsController
    property bool menuOpen: false
    property bool addFeedPanelOpen: false
    property string addFeedUrl: ""
    property int addFeedFolderId: 0
    property string addFeedFolderName: i18n.tr("No folder")
    property string addFeedNewFolderName: ""
    property string pendingAddFeedFolderName: ""
    property string newFolderName: ""
    property int selectedFeedId: 0
    property string selectedFeedTitle: ""
    property string selectedFeedRenameTitle: ""
    property int selectedFolderId: 0
    property string selectedFolderTitle: ""
    property string selectedFolderRenameTitle: ""
    property bool markAllDragActive: false
    property bool markAllDragAccepted: false
    property real markAllOriginX: 0
    property real markAllOriginY: 0
    property bool userScrolledArticleList: false
    property string activeSwipeActionLayout: appSettings.swipeActionLayout
    readonly property real pullRefreshThreshold: units.gu(7)
    property bool pullRefreshArmed: false
    readonly property real oskOverlap: Qt.inputMethod.visible && Qt.inputMethod.keyboardRectangle.height > 0
        ? Math.max(0, page.height - Qt.inputMethod.keyboardRectangle.y)
        : 0
    readonly property string accountInitial: accountSettings.displayName.length > 0
        ? accountSettings.displayName.charAt(0).toUpperCase()
        : "?"

    Settings {
        id: accountSettings
        category: "account"
        property string displayName: ""
    }

    Settings {
        id: appSettings
        category: "app"
        property string swipeActionLayout: "ut"
    }

    Connections {
        target: newsController

        onFolderAvailable: {
            if (page.pendingAddFeedFolderName.length > 0 && name === page.pendingAddFeedFolderName) {
                page.selectPendingAddFeedFolder(folderId, name)
            }
        }
    }

    Timer {
        id: pendingFolderSelectTimer
        interval: 250
        repeat: true
        running: page.pendingAddFeedFolderName.length > 0
        onTriggered: page.selectPendingAddFeedFolder(0, "")
    }

    function normalizedFolderName(value) {
        return String(value || "").trim()
    }

    function selectPendingAddFeedFolder(folderId, name) {
        var expectedName = normalizedFolderName(page.pendingAddFeedFolderName)
        if (expectedName.length === 0) {
            pendingFolderSelectTimer.stop()
            return false
        }

        var resolvedFolderId = Number(folderId || 0)
        var resolvedName = normalizedFolderName(name)
        if (resolvedFolderId <= 0 || resolvedName !== expectedName) {
            for (var i = 0; i < newsController.folders.count; ++i) {
                var folder = newsController.folders.get(i)
                if (normalizedFolderName(folder.name) === expectedName) {
                    resolvedFolderId = Number(folder.folderId || 0)
                    resolvedName = normalizedFolderName(folder.name)
                    break
                }
            }
        }

        if (resolvedFolderId <= 0 || resolvedName !== expectedName) {
            return false
        }

        page.addFeedFolderId = resolvedFolderId
        page.addFeedFolderName = resolvedName
        page.pendingAddFeedFolderName = ""
        page.addFeedNewFolderName = ""
        pendingFolderSelectTimer.stop()
        return true
    }

    function openAddFeedPanel() {
        page.addFeedUrl = ""
        page.addFeedFolderId = 0
        page.addFeedFolderName = i18n.tr("No folder")
        page.addFeedNewFolderName = ""
        page.pendingAddFeedFolderName = ""
        page.addFeedPanelOpen = true
    }

    function closeAddFeedPanel() {
        page.addFeedPanelOpen = false
        page.pendingAddFeedFolderName = ""
        Qt.inputMethod.hide()
    }

    function navigationRowSelected(type, id) {
        return type === newsController.selectedFilterType
            && Number(id) === Number(newsController.selectedFilterId)
    }

    header: PageHeader {
        id: header
        title: ""

        contents: RowLayout {
            anchors {
                fill: parent
                leftMargin: units.gu(0.5)
                rightMargin: units.gu(0.5)
            }
            spacing: units.gu(0.75)

            Item {
                Layout.preferredWidth: units.gu(3.4)
                Layout.preferredHeight: units.gu(5)

                Label {
                    anchors.centerIn: parent
                    text: "\u2630"
                    color: theme.palette.normal.backgroundText
                    font.pixelSize: units.gu(2.6)
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.menuOpen = true
                }
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: i18n.tr("Search articles")
                text: newsController.searchQuery
                onTextChanged: newsController.setSearchQuery(text)
            }

            Item {
                Layout.preferredWidth: units.gu(5)
                Layout.preferredHeight: units.gu(5)
                visible: searchField.text.length > 0

                Label {
                    anchors.centerIn: parent
                    text: "\u2715"
                    color: theme.palette.normal.backgroundText
                    font.pixelSize: units.gu(2.2)
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        searchField.text = ""
                        newsController.clearSearch()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: units.gu(5)
                Layout.preferredHeight: units.gu(5)
                radius: units.gu(2.5)
                color: "transparent"
                border.width: 2
                border.color: page.statusAccentColor()

                Item {
                    id: statusIcon
                    anchors.centerIn: parent
                    width: units.gu(2.8)
                    height: units.gu(2.8)

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: newsController.loading || newsController.syncRunning
                    }

                    Connections {
                        target: newsController
                        onLoadingChanged: {
                            if (!newsController.loading && !newsController.syncRunning) {
                                statusIcon.rotation = 0
                            }
                        }
                        onSyncRunningChanged: {
                            if (!newsController.loading && !newsController.syncRunning) {
                                statusIcon.rotation = 0
                            }
                        }
                    }

                    Canvas {
                        id: statusCanvas
                        anchors.fill: parent
                        property string paintColor: page.statusAccentColor()
                        visible: page.statusIconKind() !== "pending"
                        onVisibleChanged: requestPaint()
                        onPaintColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width
                            var h = height
                            var s = Math.min(w, h)
                            ctx.clearRect(0, 0, w, h)
                            ctx.strokeStyle = paintColor
                            ctx.fillStyle = paintColor
                            ctx.lineWidth = Math.max(2.4, s * 0.13)
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"

                            if (newsController.loading || newsController.syncRunning) {
                                ctx.beginPath()
                                ctx.arc(w / 2, h / 2, s * 0.35, Math.PI * 0.15, Math.PI * 1.55, false)
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.moveTo(w * 0.77, h * 0.30)
                                ctx.lineTo(w * 0.82, h * 0.52)
                                ctx.lineTo(w * 0.62, h * 0.45)
                                ctx.stroke()
                            } else {
                                ctx.beginPath()
                                ctx.moveTo(w * 0.22, h * 0.54)
                                ctx.lineTo(w * 0.42, h * 0.72)
                                ctx.lineTo(w * 0.78, h * 0.28)
                                ctx.stroke()
                            }
                        }

                        Connections {
                            target: newsController
                            onLoadingChanged: statusCanvas.requestPaint()
                            onSyncRunningChanged: statusCanvas.requestPaint()
                            onPendingCountChanged: statusCanvas.requestPaint()
                            onSyncStateColorChanged: statusCanvas.requestPaint()
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: page.statusIconKind() === "pending"

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.58
                            height: width
                            radius: width / 2
                            color: page.statusAccentColor()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.openStatusFromIcon()
                }
            }

            Rectangle {
                Layout.preferredWidth: units.gu(5)
                Layout.preferredHeight: units.gu(5)
                radius: units.gu(2.5)
                color: "#2c7fb8"
                border.width: 1
                border.color: "#7a7a7a"

                Image {
                    id: accountAvatarSource
                    anchors.fill: parent
                    source: newsController.accountAvatarUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                Rectangle {
                    id: accountAvatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: accountAvatarSource
                    maskSource: accountAvatarMask
                    visible: accountAvatarSource.status === Image.Ready
                }

                Label {
                    anchors.centerIn: parent
                    text: page.accountInitial
                    color: "white"
                    font.bold: true
                    visible: accountAvatarSource.status !== Image.Ready
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: pageStack.push(Qt.resolvedUrl("AccountSelectionPage.qml"), {
                        "newsController": newsController
                    })
                }
            }
        }
    }

    Component {
        id: statusDetailsDialog

        Dialog {
            id: dialog
            title: i18n.tr("Sync status")
            text: page.statusDetailsText()

            Button {
                visible: newsController.pendingCount > 0
                text: i18n.tr("Review pending changes")
                onClicked: {
                    PopupUtils.close(dialog)
                    page.openConflictResolution()
                }
            }

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Item {
        id: addFeedOverlay
        anchors.fill: parent
        visible: page.addFeedPanelOpen
        z: 30

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() {
                    addFeedFlickable.contentY = 0
                    addFeedPanelUrlField.selectAll()
                    addFeedPanelUrlField.forceActiveFocus()
                })
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.32
        }

        MouseArea {
            anchors.fill: parent
            onClicked: page.closeAddFeedPanel()
        }

        Rectangle {
            id: addFeedPanel
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            width: Math.min(parent.width, units.gu(42))
            color: theme.palette.normal.background
            border.width: 1
            border.color: "#7a7a7a"

            Timer {
                id: addFeedCreateFolderCommitTimer
                interval: 80
                repeat: false
                onTriggered: {
                    var folderName = addFeedPanelFolderNameField.text.trim()
                    page.addFeedNewFolderName = folderName
                    page.pendingAddFeedFolderName = folderName
                    if (!newsController.createFolder(page.pendingAddFeedFolderName)) {
                        page.pendingAddFeedFolderName = ""
                    } else {
                        pendingFolderSelectTimer.restart()
                    }
                }
            }

            Timer {
                id: addFeedCommitTimer
                interval: 80
                repeat: false
                onTriggered: {
                    page.addFeedUrl = addFeedPanelUrlField.text
                    if (newsController.createFeed(page.addFeedUrl, page.addFeedFolderId)) {
                        page.addFeedUrl = ""
                        page.closeAddFeedPanel()
                    }
                }
            }

            Flickable {
                id: addFeedFlickable
                anchors {
                    fill: parent
                    margins: units.gu(2)
                    bottomMargin: units.gu(2) + page.oskOverlap
                }
                clip: true
                contentWidth: width
                contentHeight: addFeedColumn.height + units.gu(2)
                boundsBehavior: Flickable.DragAndOvershootBounds

                ColumnLayout {
                    id: addFeedColumn
                    width: addFeedFlickable.width
                    spacing: units.gu(1.2)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: i18n.tr("Add feed")
                            fontSize: "x-large"
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Button {
                            Layout.preferredWidth: units.gu(5)
                            text: "\u2715"
                            onClicked: page.closeAddFeedPanel()
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Add an RSS or Atom feed to the selected Nextcloud News account.")
                        wrapMode: Text.WordWrap
                        opacity: 0.78
                    }

                    TextField {
                        id: addFeedPanelUrlField
                        Layout.fillWidth: true
                        placeholderText: i18n.tr("Feed URL")
                        text: page.addFeedUrl
                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                        onTextChanged: page.addFeedUrl = text
                        onActiveFocusChanged: {
                            if (activeFocus && text.length > 0) {
                                selectAll()
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: i18n.tr("Clear feed URL")
                        visible: page.addFeedUrl.length > 0
                        onClicked: {
                            page.addFeedUrl = ""
                            addFeedPanelUrlField.text = ""
                            addFeedPanelUrlField.forceActiveFocus()
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Folder: %1").arg(page.addFeedFolderName)
                        font.bold: true
                    }

                    Button {
                        Layout.fillWidth: true
                        text: i18n.tr("No folder")
                        color: page.addFeedFolderId === 0 ? "#2c7fb8" : theme.palette.normal.background
                        onClicked: {
                            page.addFeedFolderId = 0
                            page.addFeedFolderName = i18n.tr("No folder")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        TextField {
                            id: addFeedPanelFolderNameField
                            Layout.fillWidth: true
                            placeholderText: i18n.tr("New folder name")
                            text: page.addFeedNewFolderName
                            onTextChanged: page.addFeedNewFolderName = text
                        }

                        Button {
                            text: newsController.folderCreateRunning ? i18n.tr("Adding...") : i18n.tr("Create")
                            enabled: !newsController.folderCreateRunning
                            onClicked: {
                                Qt.inputMethod.commit()
                                addFeedPanelFolderNameField.focus = false
                                addFeedCreateFolderCommitTimer.restart()
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(Math.max(newsController.folders.count, 1) * units.gu(5.5), units.gu(22))
                        clip: true
                        model: newsController.folders

                        delegate: Button {
                            width: addFeedPanel.width - units.gu(4)
                            text: name
                            color: Number(folderId) === Number(page.addFeedFolderId) ? "#2c7fb8" : theme.palette.normal.background
                            onClicked: {
                                page.addFeedFolderId = folderId
                                page.addFeedFolderName = name
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: page.pendingAddFeedFolderName.length > 0
                            ? i18n.tr("Waiting for folder...")
                            : newsController.feedCreateRunning
                            ? i18n.tr("Adding...")
                            : i18n.tr("Add")
                        enabled: !newsController.feedCreateRunning && page.pendingAddFeedFolderName.length === 0
                        color: "#2c7fb8"
                        onClicked: {
                            Qt.inputMethod.commit()
                            addFeedPanelUrlField.focus = false
                            addFeedPanelFolderNameField.focus = false
                            addFeedCommitTimer.restart()
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: i18n.tr("Cancel")
                        onClicked: page.closeAddFeedPanel()
                    }
                }
            }
        }
    }

    Component {
        id: addFolderDialog

        Dialog {
            id: dialog
            title: i18n.tr("New folder")
            text: i18n.tr("Create a folder in Nextcloud News.")

            TextField {
                id: folderNameField
                placeholderText: i18n.tr("Folder name")
                text: page.newFolderName
                onTextChanged: page.newFolderName = text
                Component.onCompleted: forceActiveFocus()
            }

            Timer {
                id: folderCommitTimer
                interval: 80
                repeat: false
                onTriggered: {
                    page.newFolderName = folderNameField.text
                    if (newsController.createFolder(page.newFolderName)) {
                        page.newFolderName = ""
                        PopupUtils.close(dialog)
                    }
                }
            }

            Button {
                text: newsController.folderCreateRunning ? i18n.tr("Adding...") : i18n.tr("Add")
                enabled: !newsController.folderCreateRunning
                color: "#2c7fb8"
                onClicked: {
                    Qt.inputMethod.commit()
                    folderNameField.focus = false
                    folderCommitTimer.restart()
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: feedOptionsDialog

        Dialog {
            id: dialog
            title: page.selectedFeedTitle
            text: i18n.tr("Feed options")

            Label {
                text: i18n.tr("Move to folder")
                font.bold: true
            }

            Button {
                text: i18n.tr("No folder")
                onClicked: {
                    if (newsController.moveFeed(page.selectedFeedId, 0)) {
                        PopupUtils.close(dialog)
                    }
                }
            }

            ListView {
                width: parent ? parent.width : units.gu(32)
                height: Math.min(contentHeight, units.gu(18))
                clip: true
                model: newsController.folders

                delegate: Button {
                    width: parent ? parent.width : units.gu(32)
                    text: name
                    onClicked: {
                        if (newsController.moveFeed(page.selectedFeedId, folderId)) {
                            PopupUtils.close(dialog)
                        }
                    }
                }
            }

            Button {
                text: i18n.tr("Rename feed")
                onClicked: {
                    page.selectedFeedRenameTitle = page.selectedFeedTitle
                    PopupUtils.close(dialog)
                    Qt.callLater(function() { PopupUtils.open(renameFeedDialog) })
                }
            }

            Button {
                text: newsController.feedOpenExternal(page.selectedFeedId)
                    ? i18n.tr("Open in app")
                    : i18n.tr("Open in browser")
                onClicked: {
                    newsController.setFeedOpenExternal(page.selectedFeedId, !newsController.feedOpenExternal(page.selectedFeedId))
                    PopupUtils.close(dialog)
                }
            }

            Button {
                text: i18n.tr("Delete feed")
                color: "#c7162b"
                onClicked: {
                    PopupUtils.close(dialog)
                    Qt.callLater(function() { PopupUtils.open(deleteFeedConfirmDialog) })
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: renameFeedDialog

        Dialog {
            id: dialog
            title: i18n.tr("Rename feed")
            text: i18n.tr("Change the feed name on Nextcloud News.")

            TextField {
                id: feedTitleField
                placeholderText: i18n.tr("Feed name")
                text: page.selectedFeedRenameTitle
                onTextChanged: page.selectedFeedRenameTitle = text
                Component.onCompleted: forceActiveFocus()
            }

            Timer {
                id: feedRenameCommitTimer
                interval: 80
                repeat: false
                onTriggered: {
                    page.selectedFeedRenameTitle = feedTitleField.text
                    if (newsController.renameFeed(page.selectedFeedId, page.selectedFeedRenameTitle)) {
                        PopupUtils.close(dialog)
                    }
                }
            }

            Button {
                text: newsController.loading ? i18n.tr("Saving...") : i18n.tr("Save")
                enabled: !newsController.loading
                color: "#2c7fb8"
                onClicked: {
                    Qt.inputMethod.commit()
                    feedTitleField.focus = false
                    feedRenameCommitTimer.restart()
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: deleteFeedConfirmDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete feed?")
            text: i18n.tr("This will remove \"%1\" from Nextcloud News.").arg(page.selectedFeedTitle)

            Button {
                text: i18n.tr("Delete")
                color: "#c7162b"
                onClicked: {
                    if (newsController.deleteFeed(page.selectedFeedId)) {
                        PopupUtils.close(dialog)
                        page.selectedFeedId = 0
                        page.selectedFeedTitle = ""
                    }
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: folderOptionsDialog

        Dialog {
            id: dialog
            title: page.selectedFolderTitle
            text: i18n.tr("Folder options")

            Button {
                text: i18n.tr("Rename folder")
                onClicked: {
                    page.selectedFolderRenameTitle = page.selectedFolderTitle
                    PopupUtils.close(dialog)
                    Qt.callLater(function() { PopupUtils.open(renameFolderDialog) })
                }
            }

            Button {
                text: i18n.tr("Delete folder")
                color: "#c7162b"
                onClicked: {
                    PopupUtils.close(dialog)
                    Qt.callLater(function() { PopupUtils.open(deleteFolderConfirmDialog) })
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: renameFolderDialog

        Dialog {
            id: dialog
            title: i18n.tr("Rename folder")
            text: i18n.tr("Change the folder name on Nextcloud News.")

            TextField {
                id: folderTitleField
                placeholderText: i18n.tr("Folder name")
                text: page.selectedFolderRenameTitle
                onTextChanged: page.selectedFolderRenameTitle = text
                Component.onCompleted: forceActiveFocus()
            }

            Timer {
                id: folderRenameCommitTimer
                interval: 80
                repeat: false
                onTriggered: {
                    page.selectedFolderRenameTitle = folderTitleField.text
                    if (newsController.renameFolder(page.selectedFolderId, page.selectedFolderRenameTitle)) {
                        PopupUtils.close(dialog)
                    }
                }
            }

            Button {
                text: newsController.loading ? i18n.tr("Saving...") : i18n.tr("Save")
                enabled: !newsController.loading
                color: "#2c7fb8"
                onClicked: {
                    Qt.inputMethod.commit()
                    folderTitleField.focus = false
                    folderRenameCommitTimer.restart()
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: deleteFolderConfirmDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete folder?")
            text: i18n.tr("This will remove \"%1\" and all feeds in that folder from Nextcloud News.").arg(page.selectedFolderTitle)

            Button {
                text: i18n.tr("Delete")
                color: "#c7162b"
                onClicked: {
                    if (newsController.deleteFolder(page.selectedFolderId)) {
                        PopupUtils.close(dialog)
                        page.selectedFolderId = 0
                        page.selectedFolderTitle = ""
                    }
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    ListView {
        id: articleList
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(1)
        }
        clip: true
        model: newsController.model

        onContentYChanged: {
            if (contentY < -page.pullRefreshThreshold && !newsController.loading) {
                page.pullRefreshArmed = true
            }
            if (page.userScrolledArticleList && newsController.markReadWhileScrolling && moving) {
                viewportReadTimer.restart()
            }
        }

        onMovementStarted: page.userScrolledArticleList = true

        onMovementEnded: {
            if (page.pullRefreshArmed && !newsController.loading) {
                newsController.loadNews()
            }
            page.pullRefreshArmed = false
        }

        Timer {
            id: viewportReadTimer
            interval: 850
            repeat: false
            onTriggered: page.markVisibleViewportArticlesRead()
        }

        Rectangle {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: units.gu(0.6)
            }
            width: refreshPullLabel.implicitWidth + units.gu(2)
            height: units.gu(3.2)
            radius: units.gu(1.6)
            color: "#2c7fb8"
            opacity: articleList.contentY < -units.gu(2) || newsController.loading ? 0.92 : 0
            visible: opacity > 0
            z: 4

            Label {
                id: refreshPullLabel
                anchors.centerIn: parent
                text: newsController.loading
                    ? i18n.tr("Refreshing...")
                    : articleList.contentY < -page.pullRefreshThreshold
                    ? i18n.tr("Release to refresh")
                    : i18n.tr("Pull to refresh")
                color: "white"
            }
        }

        section.property: "sectionKey"
        section.criteria: ViewSection.FullString
        section.delegate: Rectangle {
            width: articleList.width
            height: sectionLabel.implicitHeight + units.gu(1.4)
            color: theme.palette.normal.background

            Label {
                id: sectionLabel
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: units.gu(0.5)
                    rightMargin: units.gu(0.5)
                }
                text: page.displaySectionLabel(section)
                font.bold: true
                opacity: 0.78
                elide: Text.ElideRight
            }
        }

        delegate: Rectangle {
            id: articleDelegate
            property int currentItemId: model.itemId
            property bool currentUnread: model.unread
            width: articleList.width
            height: units.gu(11.0)
            radius: units.gu(0.8)
            color: Math.abs(cardContent.x) > width * 0.12 ? "#2c7fb8" : "transparent"

            Label {
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }
                text: articleDelegate.actionForOffset(articleDelegate.width * 0.3) === "star"
                    ? (model.starred ? i18n.tr("Unstar") : i18n.tr("Star"))
                    : (model.unread ? i18n.tr("Mark read") : i18n.tr("Mark unread"))
                color: "white"
                font.bold: true
                opacity: cardContent.x > width * 0.08 ? 1 : 0
            }

            Label {
                anchors {
                    right: parent.right
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }
                text: articleDelegate.actionForOffset(-articleDelegate.width * 0.3) === "star"
                    ? (model.starred ? i18n.tr("Unstar") : i18n.tr("Star"))
                    : (model.unread ? i18n.tr("Mark read") : i18n.tr("Mark unread"))
                color: "white"
                font.bold: true
                opacity: cardContent.x < -width * 0.08 ? 1 : 0
            }

            Rectangle {
                id: cardContent
                x: units.gu(0.25)
                y: units.gu(0.35)
                width: parent.width - units.gu(0.5)
                height: parent.height - units.gu(0.7)
                radius: units.gu(0.75)
                color: theme.palette.normal.background
                border.width: 1
                border.color: model.unread ? "#7a7a7a" : "#a5a5a5"

                Behavior on x {
                    NumberAnimation { duration: 120 }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: units.gu(0.75)
                        rightMargin: units.gu(0.75)
                        topMargin: units.gu(0.15)
                        bottomMargin: units.gu(0.45)
                    }
                    spacing: units.gu(0.75)

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: units.gu(0.1)

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: units.gu(5.0)
                            spacing: units.gu(0.75)

                            Label {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                text: model.title
                                font.bold: model.unread
                                opacity: model.unread ? 1.0 : 0.74
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignTop
                            }

                            Label {
                                Layout.preferredWidth: Math.max(units.gu(4.5), implicitWidth)
                                Layout.alignment: Qt.AlignTop
                                text: page.relativeTime(model.pubDate)
                                horizontalAlignment: Text.AlignRight
                                opacity: 0.72
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: units.gu(2.4)
                            spacing: units.gu(0.75)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: units.gu(0.45)

                                Rectangle {
                                    Layout.preferredWidth: units.gu(2)
                                    Layout.preferredHeight: units.gu(2)
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: units.gu(1)
                                    color: model.feedFaviconLink && model.feedFaviconLink.length > 0
                                        ? "transparent"
                                        : "#4d6f8f"
                                    border.width: model.feedFaviconLink && model.feedFaviconLink.length > 0 ? 0 : 1
                                    border.color: "#7a7a7a"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: model.feedFaviconLink
                                        fillMode: Image.PreserveAspectCrop
                                        visible: model.feedFaviconLink && model.feedFaviconLink.length > 0
                                    }

                                    Label {
                                        anchors.centerIn: parent
                                        visible: !model.feedFaviconLink || model.feedFaviconLink.length === 0
                                        text: model.feedTitle && model.feedTitle.length > 0
                                            ? model.feedTitle.charAt(0).toUpperCase()
                                            : "?"
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: units.gu(1.2)
                                    }
                                }

                                Label {
                                    visible: model.starred
                                    text: "\u2605"
                                    color: "#f6c343"
                                    font.pixelSize: units.gu(1.8)
                                    opacity: model.unread ? 1.0 : 0.72
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: model.feedTitle && model.feedTitle.length > 0 ? model.feedTitle : i18n.tr("Unknown feed")
                                    opacity: model.unread ? 0.72 : 0.56
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            Row {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: units.gu(0.4)

                                Rectangle {
                                    color: model.unread ? "#2c7fb8" : "#6f6f6f"
                                    height: readStateBadgeLabel.implicitHeight + units.gu(0.35)
                                    width: readStateBadgeLabel.implicitWidth + units.gu(0.9)
                                    radius: units.gu(0.3)

                                    Label {
                                        id: readStateBadgeLabel
                                        anchors.centerIn: parent
                                        text: model.unread ? i18n.tr("Unread") : i18n.tr("Read")
                                        color: "white"
                                    }
                                }

                                Rectangle {
                                    visible: model.pendingState.length > 0
                                    color: "#c65d00"
                                    height: pendingBadgeLabel.implicitHeight + units.gu(0.35)
                                    width: pendingBadgeLabel.implicitWidth + units.gu(0.9)
                                    radius: units.gu(0.3)

                                    Label {
                                        id: pendingBadgeLabel
                                        anchors.centerIn: parent
                                        text: i18n.tr("Pending")
                                        color: "white"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: articleMouseArea
                anchors.fill: parent
                property real pressX: 0
                property bool movedHorizontally: false
                preventStealing: movedHorizontally
                onPressed: {
                    pressX = mouse.x
                    movedHorizontally = false
                    cardContent.x = 0
                }
                onPositionChanged: {
                    var delta = mouse.x - pressX
                    if (Math.abs(delta) > units.gu(1.5)) {
                        movedHorizontally = true
                    }
                    if (movedHorizontally) {
                        cardContent.x = Math.max(-articleDelegate.width * 0.45, Math.min(articleDelegate.width * 0.45, delta))
                    }
                }
                onReleased: {
                    if (Math.abs(cardContent.x) > articleDelegate.width * 0.25) {
                        var previousY = articleList.contentY
                        if (articleDelegate.actionForOffset(cardContent.x) === "star") {
                            newsController.toggleStar(model.itemId)
                        } else {
                            newsController.toggleRead(model.itemId)
                        }
                        Qt.callLater(function() {
                            articleList.contentY = previousY
                        })
                    }
                    cardContent.x = 0
                }
                onClicked: {
                    if (movedHorizontally) {
                        return
                    }
                    if (newsController.openItem(model.itemId) === "detail") {
                        pageStack.push(Qt.resolvedUrl("ArticleDetailPage.qml"), {
                            "itemId": model.itemId,
                            "newsController": newsController
                        })
                    }
                }
            }

            onVisibleChanged: {
                if (visible && page.userScrolledArticleList && newsController.markReadWhileScrolling && model.unread) {
                    visibleReadTimer.restart()
                }
            }

            Timer {
                id: visibleReadTimer
                interval: 900
                repeat: false
                onTriggered: {
                    if (articleDelegate.visible) {
                        newsController.markReadFromScroll(model.itemId)
                    }
                }
            }

            function actionForOffset(offset) {
                if (offset > 0) {
                    return page.activeSwipeActionLayout === "android" ? "star" : "read"
                }
                if (offset < 0) {
                    return page.activeSwipeActionLayout === "android" ? "read" : "star"
                }
                return ""
            }
        }
    }

    Rectangle {
        id: markAllTarget
        width: units.gu(10)
        height: width
        radius: width / 2
        x: parent.width - width - units.gu(1.4)
        y: parent.height - markAllFab.height - height - units.gu(4)
        visible: page.markAllDragActive
        color: page.markAllDragAccepted ? "#5a8f3c" : "transparent"
        border.width: 2
        border.color: page.markAllDragAccepted ? "#5a8f3c" : "#2c7fb8"
        z: 8

        Label {
            anchors.centerIn: parent
            text: "\u2713"
            font.pixelSize: units.gu(4)
            color: page.markAllDragAccepted ? "white" : "#2c7fb8"
        }
    }

    Rectangle {
        id: markAllFab
        width: units.gu(7)
        height: width
        radius: width / 2
        x: parent.width - width - units.gu(2)
        y: parent.height - height - units.gu(2)
        visible: newsController.visibleUnreadCount > 0 && !page.menuOpen
        color: "#2c7fb8"
        z: 9

        Label {
            anchors.centerIn: parent
            text: "\u2713\u2713"
            color: "white"
            font.bold: true
            font.pixelSize: units.gu(2.1)
        }

        MouseArea {
            anchors.fill: parent
            drag.target: markAllFab
            drag.axis: Drag.XAndYAxis
            property real centerX: 0
            property real centerY: 0

            onPressed: {
                page.markAllOriginX = markAllFab.x
                page.markAllOriginY = markAllFab.y
                page.markAllDragActive = true
                page.markAllDragAccepted = false
            }

            onPositionChanged: {
                centerX = markAllFab.x + markAllFab.width / 2
                centerY = markAllFab.y + markAllFab.height / 2
                page.markAllDragAccepted = centerX >= markAllTarget.x
                    && centerX <= markAllTarget.x + markAllTarget.width
                    && centerY >= markAllTarget.y
                    && centerY <= markAllTarget.y + markAllTarget.height
            }

            onReleased: {
                if (page.markAllDragAccepted) {
                    newsController.markVisibleRead()
                }
                page.markAllDragActive = false
                page.markAllDragAccepted = false
                markAllFab.x = page.markAllOriginX
                markAllFab.y = page.markAllOriginY
            }
        }
    }

    Column {
        anchors.centerIn: articleList
        width: parent.width - units.gu(6)
        spacing: units.gu(1)
        visible: newsController.model.count === 0 && !newsController.loading

        Label {
            width: parent.width
            text: newsController.searchQuery.length > 0 ? i18n.tr("No matching articles") : i18n.tr("No articles to show")
            horizontalAlignment: Text.AlignHCenter
            fontSize: "large"
        }

        Label {
            width: parent.width
            text: newsController.hasCachedItems
                ? i18n.tr("Try another feed or clear search.")
                : i18n.tr("Connect to Nextcloud while online to cache articles on this device.")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
    }

    Item {
        anchors.fill: parent
        visible: page.menuOpen
        z: 10

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.32
        }

        MouseArea {
            anchors.fill: parent
            onClicked: page.menuOpen = false
        }

        Rectangle {
        id: drawer
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        width: Math.min(parent.width * 0.82, units.gu(42))
        color: theme.palette.normal.background
        border.width: 1
        border.color: theme.palette.normal.base

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: units.gu(1.5)
            spacing: units.gu(1)

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("NextNews")
                    fontSize: "large"
                    font.bold: true
                    elide: Text.ElideRight
                }

                Item {
                    Layout.preferredWidth: units.gu(5)
                    Layout.preferredHeight: units.gu(5)

                    Label {
                        anchors.centerIn: parent
                        text: "\u2715"
                        color: theme.palette.normal.backgroundText
                        font.pixelSize: units.gu(2.2)
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.menuOpen = false
                    }
                }
            }

                ListView {
                    id: navigationList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: units.gu(0.5)
                    model: newsController.navigation
                    section.property: "groupLabel"
                    section.criteria: ViewSection.FullString
                section.delegate: Rectangle {
                    width: navigationList.width
                    height: units.gu(5)
                    color: theme.palette.normal.background

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: units.gu(1)
                            rightMargin: units.gu(1)
                        }
                        spacing: units.gu(0.8)

                        Label {
                            Layout.fillWidth: true
                            text: section
                            color: theme.palette.normal.backgroundText
                            font.bold: true
                            opacity: 0.58
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.preferredWidth: units.gu(5)
                            Layout.preferredHeight: units.gu(5)
                            visible: section === i18n.tr("Folders")
                            enabled: !newsController.folderCreateRunning

                            Label {
                                anchors.centerIn: parent
                                text: "+"
                                color: theme.palette.normal.backgroundText
                                font.pixelSize: units.gu(2.6)
                                font.bold: true
                                opacity: parent.enabled ? 1.0 : 0.45
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.enabled
                                onClicked: {
                                    page.menuOpen = false
                                    PopupUtils.open(addFolderDialog)
                                }
                            }
                        }

                        Item {
                            Layout.preferredWidth: units.gu(5)
                            Layout.preferredHeight: units.gu(5)
                            visible: section === i18n.tr("Feeds")
                            enabled: !newsController.feedCreateRunning

                            Label {
                                anchors.centerIn: parent
                                text: "+"
                                color: theme.palette.normal.backgroundText
                                font.pixelSize: units.gu(2.6)
                                font.bold: true
                                opacity: parent.enabled ? 1.0 : 0.45
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.enabled
                                onClicked: {
                                    page.menuOpen = false
                                    page.openAddFeedPanel()
                                }
                            }
                        }
                    }
                }

                delegate: Rectangle {
                    width: navigationList.width
                    height: units.gu(5.2)
                    radius: units.gu(0.5)
                    color: page.navigationRowSelected(model.type, model.id) ? "#2c7fb8" : theme.palette.normal.background
                    border.width: page.navigationRowSelected(model.type, model.id) ? 0 : 1
                    border.color: "#7a7a7a"

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: units.gu(1)
                            rightMargin: units.gu(1)
                        }
                        spacing: units.gu(0.5)

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Label {
                                anchors {
                                    fill: parent
                                }
                                text: model.label
                                color: page.navigationRowSelected(model.type, model.id) ? "white" : theme.palette.normal.backgroundText
                                font.bold: page.navigationRowSelected(model.type, model.id)
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        Label {
                            visible: model.count > 0
                            text: model.count
                            color: page.navigationRowSelected(model.type, model.id) ? "white" : theme.palette.normal.backgroundText
                            opacity: page.navigationRowSelected(model.type, model.id) ? 1.0 : 0.62
                            font.bold: page.navigationRowSelected(model.type, model.id)
                        }

                        Item {
                            Layout.preferredWidth: units.gu(5)
                            Layout.fillHeight: true
                            visible: model.type === "feed" || model.type === "folder"

                            Label {
                                anchors.centerIn: parent
                                text: "\u22ee"
                                color: page.navigationRowSelected(model.type, model.id) ? "white" : theme.palette.normal.backgroundText
                                font.pixelSize: units.gu(2.6)
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    page.menuOpen = false
                                    if (model.type === "feed") {
                                        page.selectedFeedId = model.id
                                        page.selectedFeedTitle = model.label
                                        PopupUtils.open(feedOptionsDialog)
                                    } else {
                                        page.selectedFolderId = model.id
                                        page.selectedFolderTitle = model.label
                                        PopupUtils.open(folderOptionsDialog)
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                            rightMargin: model.type === "feed" || model.type === "folder" ? units.gu(5) : 0
                        }
                        onClicked: {
                            page.menuOpen = false
                            newsController.selectFilter(model.type, model.id, model.label)
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(5)
                Label { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: units.gu(1); text: i18n.tr("Language"); color: theme.palette.normal.backgroundText; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: { page.menuOpen = false; pageStack.push(Qt.resolvedUrl("LanguageSelectionPage.qml")) } }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(5)
                Label { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: units.gu(1); text: i18n.tr("Account"); color: theme.palette.normal.backgroundText; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: { page.menuOpen = false; pageStack.push(Qt.resolvedUrl("AccountSelectionPage.qml"), { "newsController": newsController }) } }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(5)
                Label { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: units.gu(1); text: i18n.tr("Settings"); color: theme.palette.normal.backgroundText; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: { page.menuOpen = false; pageStack.push(Qt.resolvedUrl("SettingsPage.qml"), { "newsController": newsController, "swipeActionLayout": page.activeSwipeActionLayout, "newsListPage": page }) } }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(5)
                Label { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: units.gu(1); text: i18n.tr("About"); color: theme.palette.normal.backgroundText; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: { page.menuOpen = false; pageStack.push(Qt.resolvedUrl("AboutPage.qml")) } }
            }
        }
        }
    }

    function displaySectionLabel(sectionKey) {
        var value = String(sectionKey || "")
        var split = value.indexOf("|")
        return split >= 0 ? value.slice(split + 1) : value
    }

    function markVisibleViewportArticlesRead() {
        if (!newsController.markReadWhileScrolling || !page.userScrolledArticleList) {
            return
        }
        var seen = {}
        var step = units.gu(6)
        for (var y = units.gu(1); y < articleList.height - units.gu(1); y += step) {
            var item = articleList.itemAt(articleList.width / 2, articleList.contentY + y)
            if (!item || !item.currentItemId || seen[item.currentItemId]) {
                continue
            }
            seen[item.currentItemId] = true
            if (item.currentUnread) {
                newsController.markReadFromScroll(item.currentItemId)
            }
        }
    }

    function relativeTime(seconds) {
        if (!seconds || seconds <= 0) {
            return ""
        }
        var diff = Math.max(0, Math.floor(Date.now() / 1000) - Number(seconds))
        if (diff < 3600) {
            return i18n.tr("%1m").arg(Math.max(1, Math.floor(diff / 60)))
        }
        if (diff < 86400) {
            return i18n.tr("%1h").arg(Math.floor(diff / 3600))
        }
        var d = new Date(Number(seconds) * 1000)
        return Qt.formatDate(d, "d MMM")
    }

    function statusIconKind() {
        if (newsController.loading || newsController.syncRunning) {
            return "syncing"
        }
        if (newsController.pendingCount > 0) {
            return "pending"
        }
        return "synced"
    }

    function statusAccentColor() {
        if (newsController.loading || newsController.syncRunning) {
            return "#2c7fb8"
        }
        if (newsController.pendingCount > 0) {
            return "#c65d00"
        }
        return newsController.syncStateColor
    }

    function setSwipeActionLayout(value) {
        var normalized = value === "android" ? "android" : "ut"
        page.activeSwipeActionLayout = normalized
        appSettings.swipeActionLayout = normalized
    }

    function statusDetailsText() {
        var parts = []
        if (newsController.statusText.length > 0) {
            parts.push(newsController.statusText)
        }
        if (newsController.syncStateText.length > 0) {
            parts.push(i18n.tr("Sync: %1").arg(newsController.syncStateText))
        }
        if (newsController.pendingCount > 0) {
            parts.push(i18n.tr("%1 local changes are waiting for sync.").arg(newsController.pendingCount))
        }
        if (parts.length === 0) {
            parts.push(i18n.tr("No status message."))
        }
        return parts.join("\n")
    }

    function openStatusFromIcon() {
        if (newsController.pendingCount > 0) {
            page.openConflictResolution()
            return
        }
        PopupUtils.open(statusDetailsDialog)
    }

    function openConflictResolution() {
        pageStack.push(Qt.resolvedUrl("ConflictResolutionPage.qml"), {
            "newsController": newsController
        })
    }
}
