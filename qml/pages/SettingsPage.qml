import QtQuick 2.7
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Lomiri.Components 1.3

Page {
    id: page

    property var newsController
    property string swipeActionLayout: appSettings.swipeActionLayout
    property var newsListPage

    header: PageHeader {
        id: header
        title: i18n.tr("Settings")
    }

    Settings {
        id: appSettings
        category: "app"
        property string swipeActionLayout: "ut"
    }

    Flickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentWidth: width
        contentHeight: contentColumn.height + units.gu(6)
        clip: true

        ColumnLayout {
            id: contentColumn
            width: parent.width - units.gu(4)
            x: units.gu(2)
            y: units.gu(2)
            spacing: units.gu(1.4)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: syncSettingsColumn.implicitHeight + units.gu(2)
                radius: units.gu(0.6)
                color: "transparent"
                border.width: 1
                border.color: "#7a7a7a"

                ColumnLayout {
                    id: syncSettingsColumn
                    anchors {
                        fill: parent
                        margins: units.gu(1)
                    }
                    spacing: units.gu(1)

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Sync")
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: i18n.tr("Sync while app is active")
                            wrapMode: Text.WordWrap
                        }

                        Switch {
                            checked: newsController.autoSyncEnabled
                            onCheckedChanged: newsController.setAutoSyncEnabled(checked)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: i18n.tr("Sync on startup")
                            wrapMode: Text.WordWrap
                        }

                        Switch {
                            checked: newsController.syncOnStartup
                            onCheckedChanged: newsController.setSyncOnStartup(checked)
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Active sync interval")
                        opacity: newsController.autoSyncEnabled ? 0.72 : 0.42
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)
                        opacity: newsController.autoSyncEnabled ? 1.0 : 0.42
                        enabled: newsController.autoSyncEnabled

                        Button {
                            Layout.fillWidth: true
                            text: "5m"
                            color: newsController.syncIntervalMinutes === 5 ? "#2c7fb8" : theme.palette.normal.background
                            onClicked: newsController.setSyncIntervalMinutes(5)
                        }

                        Button {
                            Layout.fillWidth: true
                            text: "15m"
                            color: newsController.syncIntervalMinutes === 15 ? "#2c7fb8" : theme.palette.normal.background
                            onClicked: newsController.setSyncIntervalMinutes(15)
                        }

                        Button {
                            Layout.fillWidth: true
                            text: "30m"
                            color: newsController.syncIntervalMinutes === 30 ? "#2c7fb8" : theme.palette.normal.background
                            onClicked: newsController.setSyncIntervalMinutes(30)
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Ubuntu Touch does not provide Android-style background services for this app. Sync runs while NextNews is open or activated.")
                        wrapMode: Text.WordWrap
                        opacity: 0.68
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: listSettingsColumn.implicitHeight + units.gu(2)
                radius: units.gu(0.6)
                color: "transparent"
                border.width: 1
                border.color: "#7a7a7a"

                ColumnLayout {
                    id: listSettingsColumn
                    anchors {
                        fill: parent
                        margins: units.gu(1)
                    }
                    spacing: units.gu(1)

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("List")
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: i18n.tr("Oldest articles first")
                            wrapMode: Text.WordWrap
                        }

                        Switch {
                            checked: newsController.sortOldestFirst
                            onCheckedChanged: newsController.setSortOldestFirst(checked)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: i18n.tr("Open articles in browser directly")
                            wrapMode: Text.WordWrap
                        }

                        Switch {
                            checked: newsController.openInBrowserDirectly
                            onCheckedChanged: newsController.setOpenInBrowserDirectly(checked)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: i18n.tr("Reverse left/right actions")
                            wrapMode: Text.WordWrap
                        }

                        Switch {
                            checked: page.swipeActionLayout === "android"
                            onCheckedChanged: page.setSwipeActionLayout(checked ? "android" : "ut")
                        }
                    }

                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: searchSettingsColumn.implicitHeight + units.gu(2)
                radius: units.gu(0.6)
                color: "transparent"
                border.width: 1
                border.color: "#7a7a7a"

                ColumnLayout {
                    id: searchSettingsColumn
                    anchors {
                        fill: parent
                        margins: units.gu(1)
                    }
                    spacing: units.gu(1)

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Search")
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        Button {
                            Layout.fillWidth: true
                            text: i18n.tr("Title")
                            color: newsController.searchIn === "title" ? "#2c7fb8" : theme.palette.normal.background
                            onClicked: newsController.setSearchIn("title")
                        }

                        Button {
                            Layout.fillWidth: true
                            text: i18n.tr("Content")
                            color: newsController.searchIn === "body" ? "#2c7fb8" : theme.palette.normal.background
                            onClicked: newsController.setSearchIn("body")
                        }

                        Button {
                            Layout.fillWidth: true
                            text: i18n.tr("Both")
                            color: newsController.searchIn === "both" ? "#2c7fb8" : theme.palette.normal.background
                            onClicked: newsController.setSearchIn("both")
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        page.swipeActionLayout = appSettings.swipeActionLayout === "android" || page.swipeActionLayout === "android" ? "android" : "ut"
    }

    function setSwipeActionLayout(value) {
        var normalized = value === "android" ? "android" : "ut"
        page.swipeActionLayout = normalized
        appSettings.swipeActionLayout = normalized
        if (page.newsListPage && page.newsListPage.setSwipeActionLayout) {
            page.newsListPage.setSwipeActionLayout(normalized)
        }
    }
}
