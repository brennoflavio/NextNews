import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../backend/NewsApiCore.js" as NewsApiCore

Page {
    id: page

    property int itemId: 0
    property var newsController
    property var article: newsController ? newsController.getItem(itemId) : null

    header: PageHeader {
        id: header
        title: article ? article.title : i18n.tr("Article")

        trailingActionBar.actions: [
            Action {
                iconName: "external-link"
                text: i18n.tr("Open")
                visible: article && article.url.length > 0
                onTriggered: Qt.openUrlExternally(article.url)
            },
            Action {
                iconName: "share"
                text: i18n.tr("Share")
                visible: article && article.url.length > 0
                onTriggered: page.shareArticle()
            },
            Action {
                iconName: article && article.starred ? "starred" : "non-starred"
                text: article && article.starred ? i18n.tr("Unstar") : i18n.tr("Star")
                onTriggered: {
                    newsController.toggleStar(page.itemId)
                    page.article = newsController.getItem(page.itemId)
                }
            },
            Action {
                iconName: "ok"
                text: article && article.unread ? i18n.tr("Mark read") : i18n.tr("Mark unread")
                onTriggered: {
                    if (page.article) {
                        newsController.markRead(page.itemId, page.article.unread)
                        page.article = newsController.getItem(page.itemId)
                    }
                }
            }
        ]
    }

    Flickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
        }
        contentWidth: width
        contentHeight: contentColumn.height
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            spacing: units.gu(1.4)

            Label {
                width: parent.width
                text: article ? article.title : i18n.tr("Article not cached")
                wrapMode: Text.WordWrap
                fontSize: "x-large"
                font.bold: true
            }

            RowLayout {
                width: parent.width
                visible: article !== null
                spacing: units.gu(0.8)

                Rectangle {
                    Layout.preferredWidth: units.gu(3.4)
                    Layout.preferredHeight: units.gu(3.4)
                    radius: units.gu(1.7)
                    color: "#2c7fb8"
                    clip: true

                    Image {
                        id: faviconImage
                        anchors.fill: parent
                        source: page.feedFavicon()
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    Label {
                        anchors.centerIn: parent
                        text: page.feedInitial()
                        color: "white"
                        font.bold: true
                        visible: !faviconImage.visible
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.1)

                    Label {
                        Layout.fillWidth: true
                        text: page.feedTitle()
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Label {
                        Layout.fillWidth: true
                        text: article ? [article.author, page.dateText(article.pubDate)].filter(function(v) { return v && v.length > 0 }).join(" - ") : ""
                        visible: text.length > 0
                        opacity: 0.65
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            Row {
                spacing: units.gu(1)
                visible: article !== null

                Label {
                    text: article && article.unread ? i18n.tr("Unread") : i18n.tr("Read")
                    color: "#2c7fb8"
                }

                Label {
                    text: article && article.starred ? "\u2605" : "\u2606"
                    color: article && article.starred ? "#f6c343" : theme.palette.normal.backgroundText
                    opacity: article && article.starred ? 1.0 : 0.42
                    font.pixelSize: units.gu(2)
                }

                Label {
                    visible: article && article.pendingState.length > 0
                    text: i18n.tr("Pending sync")
                    color: "#b37a2a"
                }
            }

            Text {
                width: parent.width
                text: article ? page.articleBodyRichText() : page.escapeHtml(i18n.tr("Open this article online once to cache it for offline reading."))
                textFormat: Text.RichText
                wrapMode: Text.WordWrap
                lineHeight: 1.2
                color: theme.palette.normal.backgroundText
                linkColor: "#2c7fb8"
                onLinkActivated: Qt.openUrlExternally(link)
            }

        }
    }

    Component.onCompleted: {
        if (article && article.unread) {
            newsController.markRead(itemId, true)
            article = newsController.getItem(itemId)
        }
    }

    function dateText(seconds) {
        if (!seconds || seconds <= 0) {
            return ""
        }
        return Qt.formatDateTime(new Date(Number(seconds) * 1000), Qt.DefaultLocaleShortDate)
    }

    function feedTitle() {
        if (!article) {
            return i18n.tr("Unknown feed")
        }
        if (article.feedTitle && article.feedTitle.length > 0) {
            return article.feedTitle
        }
        var feed = newsController && newsController.feedForId ? newsController.feedForId(article.feedId) : null
        if (feed && feed.title && feed.title.length > 0) {
            return feed.title
        }
        return i18n.tr("Unknown feed")
    }

    function feedFavicon() {
        if (!article) {
            return ""
        }
        if (article.feedFaviconLink && article.feedFaviconLink.length > 0) {
            return article.feedFaviconLink
        }
        var feed = newsController && newsController.feedForId ? newsController.feedForId(article.feedId) : null
        return feed && feed.faviconLink ? feed.faviconLink : ""
    }

    function feedInitial() {
        var title = feedTitle()
        return title.length > 0 && title !== i18n.tr("Unknown feed") ? title.charAt(0).toUpperCase() : "?"
    }

    function articleBodyRichText() {
        if (!article || !article.body || article.body.length === 0) {
            return "<p>" + escapeHtml(i18n.tr("Open this article online once to cache it for offline reading.")) + "</p>"
        }
        return "<p>" + linkifyPlainText(NewsApiCore.stripHtml(article.body)).replace(/\n/g, "<br>") + "</p>"
    }

    function linkifyPlainText(value) {
        var escaped = escapeHtml(value)
        return escaped.replace(/(https?:\/\/[^\s<]+)/g, function(url) {
            var cleanUrl = url
            var suffix = ""
            while (cleanUrl.length > 0 && [".", ",", ";", ":", ")", "]"].indexOf(cleanUrl.charAt(cleanUrl.length - 1)) >= 0) {
                suffix = cleanUrl.charAt(cleanUrl.length - 1) + suffix
                cleanUrl = cleanUrl.slice(0, -1)
            }
            return "<a href=\"" + cleanUrl + "\">" + cleanUrl + "</a>" + suffix
        })
    }

    function escapeHtml(value) {
        return String(value || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;")
    }

    function shareTitle() {
        if (!article) {
            return i18n.tr("Article")
        }
        return article.title || i18n.tr("Article")
    }

    function shareText() {
        if (!article) {
            return ""
        }
        var parts = []
        if (article.title && article.title.length > 0) {
            parts.push(article.title)
        }
        if (article.url && article.url.length > 0) {
            parts.push(article.url)
        }
        return parts.join("\n")
    }

    function shareArticle() {
        var text = shareText()
        if (text.length === 0) {
            return
        }
        var props = {
            "shareTitle": shareTitle(),
            "shareText": text
        }
        var pageObject = pageStack.push(Qt.resolvedUrl("../backend/ArticleShareExportPage.qml"), props)
        if (pageObject) {
            pageObject.shareFinished.connect(function() { pageStack.pop() })
            pageObject.shareFailed.connect(function(message) {
                pageStack.pop()
                console.log("NextNews ContentHub share failed: " + message)
            })
            return
        }
        pageObject = pageStack.push(Qt.resolvedUrl("../backend/ArticleShareExportPageUbuntu.qml"), props)
        if (pageObject) {
            pageObject.shareFinished.connect(function() { pageStack.pop() })
            pageObject.shareFailed.connect(function(message) {
                pageStack.pop()
                console.log("NextNews ContentHub share failed: " + message)
            })
        }
    }
}
