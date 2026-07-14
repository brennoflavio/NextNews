import QtQuick 2.7
import QtQuick.LocalStorage 2.0 as Sql
import "NewsApiCore.js" as NewsApiCore

Item {
    id: cache

    readonly property string pendingNone: ""
    readonly property string pendingState: "state"
    readonly property string pendingStar: "star"

    property var database: null

    Component.onCompleted: open()

    function ensureOpen() {
        if (!database) {
            open()
        }
    }

    function open() {
        database = Sql.LocalStorage.openDatabaseSync("NextNewsSync", "1.0", "NextNews sync cache", 8 * 1024 * 1024)
        database.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS folders (id INTEGER PRIMARY KEY, name TEXT)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS feeds (id INTEGER PRIMARY KEY, folder_id INTEGER, title TEXT, url TEXT, favicon_link TEXT, unread_count INTEGER)")
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS items (" +
                "id INTEGER PRIMARY KEY, feed_id INTEGER, guid_hash TEXT, guid TEXT, title TEXT, url TEXT, author TEXT, body TEXT, " +
                "pub_date INTEGER, last_modified INTEGER, unread INTEGER, starred INTEGER, media_thumbnail TEXT, pending_state TEXT, updated_at INTEGER)"
            )
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_items_feed ON items(feed_id)")
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_items_pub_date ON items(pub_date DESC)")
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_items_pending ON items(pending_state)")
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS pending_management (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT, target_id INTEGER, payload TEXT, created_at INTEGER)"
            )
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_pending_management_created ON pending_management(created_at)")
            try {
                tx.executeSql("ALTER TABLE feeds ADD COLUMN open_external INTEGER DEFAULT 0")
            } catch (error) {
                // Existing cache already has this column.
            }
        })
    }

    function loadFolders() {
        ensureOpen()
        var rows = []
        database.readTransaction(function(tx) {
            var result = tx.executeSql("SELECT id, name FROM folders ORDER BY name COLLATE NOCASE")
            for (var i = 0; i < result.rows.length; ++i) {
                rows.push(rowToFolder(result.rows.item(i)))
            }
        })
        return rows
    }

    function loadFeeds() {
        ensureOpen()
        var rows = []
        database.readTransaction(function(tx) {
            var result = tx.executeSql("SELECT id, folder_id, title, url, favicon_link, unread_count, open_external FROM feeds ORDER BY title COLLATE NOCASE")
            for (var i = 0; i < result.rows.length; ++i) {
                rows.push(rowToFeed(result.rows.item(i)))
            }
        })
        return rows
    }

    function loadItems() {
        ensureOpen()
        var rows = []
        database.readTransaction(function(tx) {
            var result = tx.executeSql(
                "SELECT id, feed_id, guid_hash, guid, title, url, author, body, pub_date, last_modified, unread, starred, media_thumbnail, pending_state " +
                "FROM items ORDER BY pub_date DESC, id DESC"
            )
            for (var i = 0; i < result.rows.length; ++i) {
                rows.push(rowToItem(result.rows.item(i)))
            }
        })
        return rows
    }

    function loadPendingItems() {
        ensureOpen()
        var rows = []
        database.readTransaction(function(tx) {
            var result = tx.executeSql(
                "SELECT id, feed_id, guid_hash, guid, title, url, author, body, pub_date, last_modified, unread, starred, media_thumbnail, pending_state " +
                "FROM items WHERE pending_state != '' ORDER BY updated_at ASC"
            )
            for (var i = 0; i < result.rows.length; ++i) {
                rows.push(rowToItem(result.rows.item(i)))
            }
        })
        return rows
    }

    function clearAllPendingItems() {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("UPDATE items SET pending_state = '', updated_at = ? WHERE pending_state != ''", [Date.now()])
        })
    }

    function loadPendingManagementOperations() {
        ensureOpen()
        var rows = []
        database.readTransaction(function(tx) {
            var result = tx.executeSql("SELECT id, kind, target_id, payload FROM pending_management ORDER BY created_at ASC")
            for (var i = 0; i < result.rows.length; ++i) {
                rows.push(rowToPendingManagement(result.rows.item(i)))
            }
        })
        return rows
    }

    function queueManagementOperation(kind, targetId, payload) {
        ensureOpen()
        var json = JSON.stringify(payload || {})
        database.transaction(function(tx) {
            tx.executeSql("DELETE FROM pending_management WHERE kind = ? AND target_id = ?", [kind, targetId])
            tx.executeSql(
                "INSERT INTO pending_management (kind, target_id, payload, created_at) VALUES (?, ?, ?, ?)",
                [kind, Number(targetId || 0), json, Date.now()]
            )
        })
    }

    function removePendingManagementOperation(operationId) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("DELETE FROM pending_management WHERE id = ?", [operationId])
        })
    }

    function clearPendingManagementOperations() {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("DELETE FROM pending_management")
        })
    }

    function saveFolders(folders) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("DELETE FROM folders")
            for (var i = 0; i < folders.length; ++i) {
                tx.executeSql("INSERT OR REPLACE INTO folders (id, name) VALUES (?, ?)", [folders[i].folderId, folders[i].name])
            }
        })
    }

    function saveFeeds(feeds) {
        ensureOpen()
        database.transaction(function(tx) {
            var existingOpenExternal = {}
            var existing = tx.executeSql("SELECT id, open_external FROM feeds")
            for (var existingIndex = 0; existingIndex < existing.rows.length; ++existingIndex) {
                var existingRow = existing.rows.item(existingIndex)
                existingOpenExternal[Number(existingRow.id)] = Number(existingRow.open_external || 0) === 1 ? 1 : 0
            }
            tx.executeSql("DELETE FROM feeds")
            var feedIds = []
            for (var i = 0; i < feeds.length; ++i) {
                var feed = feeds[i]
                feedIds.push(Number(feed.feedId || 0))
                var openExternal = existingOpenExternal[Number(feed.feedId || 0)] || (feed.openExternal ? 1 : 0)
                tx.executeSql(
                    "INSERT OR REPLACE INTO feeds (id, folder_id, title, url, favicon_link, unread_count, open_external) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    [feed.feedId, feed.folderId, feed.title, feed.url, feed.faviconLink, feed.unreadCount || 0, openExternal]
                )
            }
            if (feedIds.length === 0) {
                tx.executeSql("DELETE FROM items WHERE pending_state IS NULL OR pending_state = ''")
            } else {
                tx.executeSql("DELETE FROM items WHERE (pending_state IS NULL OR pending_state = '') AND feed_id NOT IN (" + feedIds.join(",") + ")")
            }
        })
    }

    function removeFeed(feedId) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("DELETE FROM feeds WHERE id = ?", [feedId])
            tx.executeSql("DELETE FROM items WHERE feed_id = ?", [feedId])
        })
    }

    function removeFolder(folderId) {
        ensureOpen()
        database.transaction(function(tx) {
            var feeds = tx.executeSql("SELECT id FROM feeds WHERE folder_id = ?", [folderId])
            for (var i = 0; i < feeds.rows.length; ++i) {
                var feedId = feeds.rows.item(i).id
                tx.executeSql("DELETE FROM items WHERE feed_id = ?", [feedId])
            }
            tx.executeSql("DELETE FROM feeds WHERE folder_id = ?", [folderId])
            tx.executeSql("DELETE FROM folders WHERE id = ?", [folderId])
        })
    }

    function renameFeed(feedId, title) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("UPDATE feeds SET title = ? WHERE id = ?", [title, feedId])
        })
    }

    function renameFolder(folderId, name) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("UPDATE folders SET name = ? WHERE id = ?", [name, folderId])
        })
    }

    function setFeedOpenExternal(feedId, openExternal) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("UPDATE feeds SET open_external = ? WHERE id = ?", [openExternal ? 1 : 0, feedId])
        })
    }

    function saveItems(items) {
        ensureOpen()
        var now = Date.now()
        database.transaction(function(tx) {
            for (var i = 0; i < items.length; ++i) {
                var item = items[i]
                var existing = tx.executeSql("SELECT pending_state, unread, starred FROM items WHERE id = ?", [item.itemId])
                var pending = existing.rows.length > 0 ? String(existing.rows.item(0).pending_state || "") : ""
                var unread = pending.length > 0 ? Number(existing.rows.item(0).unread || 0) : (item.unread ? 1 : 0)
                var starred = pending.length > 0 ? Number(existing.rows.item(0).starred || 0) : (item.starred ? 1 : 0)
                tx.executeSql(
                    "INSERT OR REPLACE INTO items " +
                    "(id, feed_id, guid_hash, guid, title, url, author, body, pub_date, last_modified, unread, starred, media_thumbnail, pending_state, updated_at) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    [
                        item.itemId, item.feedId, item.guidHash, item.guid, item.title, item.url, item.author,
                        item.body, item.pubDate, item.lastModified, unread, starred, item.mediaThumbnail,
                        pending, now
                    ]
                )
            }
        })
    }

    function updateLocalReadState(itemId, unread, pending) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql(
                "UPDATE items SET unread = ?, pending_state = ?, updated_at = ? WHERE id = ?",
                [unread ? 1 : 0, pending ? pendingState : pendingNone, Date.now(), itemId]
            )
        })
    }

    function updateLocalReadStates(itemIds, unread, pending) {
        ensureOpen()
        var now = Date.now()
        database.transaction(function(tx) {
            for (var i = 0; i < itemIds.length; ++i) {
                tx.executeSql(
                    "UPDATE items SET unread = ?, pending_state = ?, updated_at = ? WHERE id = ?",
                    [unread ? 1 : 0, pending ? pendingState : pendingNone, now, itemIds[i]]
                )
            }
        })
    }

    function updateLocalStarState(itemId, starred, pending) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql(
                "UPDATE items SET starred = ?, pending_state = ?, updated_at = ? WHERE id = ?",
                [starred ? 1 : 0, pending ? pendingStar : pendingNone, Date.now(), itemId]
            )
        })
    }

    function clearPending(itemId) {
        ensureOpen()
        database.transaction(function(tx) {
            tx.executeSql("UPDATE items SET pending_state = '', updated_at = ? WHERE id = ?", [Date.now(), itemId])
        })
    }

    function rowToFolder(row) {
        return { "folderId": Number(row.id), "name": row.name || "" }
    }

    function rowToFeed(row) {
        return {
            "feedId": Number(row.id),
            "folderId": Number(row.folder_id || 0),
            "title": row.title || "",
            "url": row.url || "",
            "faviconLink": row.favicon_link || "",
            "unreadCount": Number(row.unread_count || 0),
            "openExternal": Number(row.open_external || 0) === 1
        }
    }

    function rowToItem(row) {
        var body = row.body || ""
        return {
            "itemId": Number(row.id),
            "feedId": Number(row.feed_id || 0),
            "guidHash": row.guid_hash || "",
            "guid": row.guid || "",
            "title": row.title || i18n.tr("Untitled article"),
            "url": row.url || "",
            "author": row.author || "",
            "body": body,
            "preview": NewsApiCore.stripHtml(body),
            "pubDate": Number(row.pub_date || 0),
            "lastModified": Number(row.last_modified || 0),
            "unread": Number(row.unread || 0) === 1,
            "starred": Number(row.starred || 0) === 1,
            "mediaThumbnail": row.media_thumbnail || "",
            "pendingState": row.pending_state || ""
        }
    }

    function rowToPendingManagement(row) {
        var payload = {}
        try {
            payload = JSON.parse(row.payload || "{}")
        } catch (error) {
            payload = {}
        }
        return {
            "operationId": Number(row.id || 0),
            "kind": row.kind || "",
            "targetId": Number(row.target_id || 0),
            "payload": payload
        }
    }
}
