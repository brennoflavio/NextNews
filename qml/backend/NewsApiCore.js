.pragma library

function normalizeServerUrl(value) {
    if (!value) {
        return ""
    }

    var url = String(value).trim()
    while (url.length > 0 && url.charAt(url.length - 1) === "/") {
        url = url.slice(0, -1)
    }
    if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0) {
        return url
    }
    return "https://" + url
}

function apiBaseUrl(serverUrl) {
    return normalizeServerUrl(serverUrl) + "/index.php/apps/news/api/v1-2"
}

function foldersUrl(serverUrl) {
    return apiBaseUrl(serverUrl) + "/folders"
}

function folderUrl(serverUrl, folderId) {
    return foldersUrl(serverUrl) + "/" + encodeURIComponent(folderId)
}

function feedsUrl(serverUrl) {
    return apiBaseUrl(serverUrl) + "/feeds"
}

function feedUrl(serverUrl, feedId) {
    return feedsUrl(serverUrl) + "/" + encodeURIComponent(feedId)
}

function moveFeedUrl(serverUrl, feedId) {
    return feedUrl(serverUrl, feedId) + "/move"
}

function renameFeedUrl(serverUrl, feedId) {
    return feedUrl(serverUrl, feedId) + "/rename"
}

function renameFeedPayload(title) {
    return { "feedTitle": String(title || "").trim() }
}

function renameFolderPayload(name) {
    return { "name": String(name || "").trim() }
}

function createFeedPayload(feedUrl, folderId) {
    return {
        "url": String(feedUrl || "").trim(),
        "folderId": Number(folderId || 0)
    }
}

function createFolderPayload(name) {
    return { "name": String(name || "").trim() }
}

function moveFeedPayload(folderId) {
    return { "folderId": Number(folderId || 0) }
}

function itemsUrl(serverUrl, type, id, getRead) {
    var query = [
        "batchSize=100",
        "offset=0",
        "type=" + encodeURIComponent(type),
        "id=" + encodeURIComponent(id),
        "getRead=" + (getRead ? "true" : "false"),
        "oldestFirst=false"
    ].join("&")
    return apiBaseUrl(serverUrl) + "/items?" + query
}

function markReadUrl(serverUrl, read) {
    return apiBaseUrl(serverUrl) + (read ? "/items/read/multiple" : "/items/unread/multiple")
}

function starUrl(serverUrl, starred) {
    return apiBaseUrl(serverUrl) + (starred ? "/items/star/multiple" : "/items/unstar/multiple")
}

function idsPayload(itemIds) {
    var ids = []
    for (var i = 0; i < itemIds.length; ++i) {
        ids.push(Number(itemIds[i]))
    }
    return { "items": ids }
}

function starPayload(items) {
    var payload = []
    for (var i = 0; i < items.length; ++i) {
        payload.push({
            "feedId": Number(items[i].feedId || 0),
            "guidHash": String(items[i].guidHash || "")
        })
    }
    return { "items": payload }
}

function parseWrappedArray(responseText, key) {
    var parsed
    try {
        parsed = JSON.parse(responseText)
    } catch (error) {
        return { "ok": false, "error": "parse-error" }
    }

    if (!parsed || !parsed[key] || typeof parsed[key].length !== "number") {
        return { "ok": false, "error": "missing-" + key }
    }

    return { "ok": true, "items": parsed[key] }
}

function parseFolders(responseText) {
    var result
    if (!responseText || String(responseText).trim().length === 0) {
        return { "ok": true, "folders": [] }
    }

    var parsed
    try {
        parsed = JSON.parse(responseText)
    } catch (error) {
        return { "ok": false, "error": "parse-error" }
    }

    if (parsed && parsed.folders && typeof parsed.folders.length === "number") {
        result = { "ok": true, "items": parsed.folders }
    } else if (parsed && typeof parsed.length === "number") {
        result = { "ok": true, "items": parsed }
    } else {
        return { "ok": false, "error": "missing-folders" }
    }

    var folders = []
    for (var i = 0; i < result.items.length; ++i) {
        var row = result.items[i]
        folders.push({
            "folderId": Number(row.id || 0),
            "name": row.name !== undefined && row.name !== null ? String(row.name) : ""
        })
    }
    return { "ok": true, "folders": folders }
}

function parseFeeds(responseText) {
    var result
    if (!responseText || String(responseText).trim().length === 0) {
        return { "ok": true, "feeds": [] }
    }

    var parsed
    try {
        parsed = JSON.parse(responseText)
    } catch (error) {
        return { "ok": false, "error": "parse-error" }
    }

    if (parsed && parsed.feeds && typeof parsed.feeds.length === "number") {
        result = { "ok": true, "items": parsed.feeds }
    } else if (parsed && typeof parsed.length === "number") {
        result = { "ok": true, "items": parsed }
    } else {
        return { "ok": false, "error": "missing-feeds" }
    }

    var feeds = []
    for (var i = 0; i < result.items.length; ++i) {
        var row = result.items[i]
        feeds.push({
            "feedId": Number(row.id || 0),
            "folderId": row.folderId === null || row.folderId === undefined ? 0 : Number(row.folderId),
            "title": row.title !== undefined && row.title !== null ? String(row.title) : "",
            "url": row.url !== undefined && row.url !== null ? String(row.url) : "",
            "faviconLink": row.faviconLink !== undefined && row.faviconLink !== null ? String(row.faviconLink) : "",
            "unreadCount": Number(row.unreadCount || 0),
            "openExternal": false
        })
    }
    return { "ok": true, "feeds": feeds }
}

function parseItems(responseText) {
    var result = parseWrappedArray(responseText, "items")
    if (!result.ok) {
        return result
    }
    var items = []
    for (var i = 0; i < result.items.length; ++i) {
        items.push(parseItem(result.items[i]))
    }
    return { "ok": true, "items": items }
}

function parseItem(row) {
    return {
        "itemId": Number(row.id || 0),
        "feedId": Number(row.feedId || 0),
        "guidHash": row.guidHash !== undefined && row.guidHash !== null ? String(row.guidHash) : "",
        "guid": row.guid !== undefined && row.guid !== null ? String(row.guid) : "",
        "title": row.title !== undefined && row.title !== null && String(row.title).length > 0 ? String(row.title) : "Untitled article",
        "url": row.url !== undefined && row.url !== null ? String(row.url) : "",
        "author": row.author !== undefined && row.author !== null ? String(row.author) : "",
        "body": row.body !== undefined && row.body !== null ? String(row.body) : "",
        "pubDate": Number(row.pubDate || 0),
        "lastModified": Number(row.lastModified || 0),
        "unread": row.unread === true,
        "starred": row.starred === true,
        "mediaThumbnail": row.mediaThumbnail !== undefined && row.mediaThumbnail !== null ? String(row.mediaThumbnail) : ""
    }
}

function stripHtml(value) {
    return decodeHtmlEntities(String(value || "")
        .replace(/<[^>]+>/g, " ")
        .replace(/&nbsp;/g, " "))
        .replace(/\s+/g, " ")
        .trim()
}

function decodeHtmlEntities(value) {
    var named = {
        "amp": "&",
        "apos": "'",
        "gt": ">",
        "lt": "<",
        "nbsp": " ",
        "quot": "\""
    }

    return String(value || "")
        .replace(/&#x([0-9a-fA-F]+);/g, function(match, code) {
            return String.fromCharCode(parseInt(code, 16))
        })
        .replace(/&#([0-9]+);/g, function(match, code) {
            return String.fromCharCode(parseInt(code, 10))
        })
        .replace(/&([a-zA-Z]+);/g, function(match, name) {
            return named[name] !== undefined ? named[name] : match
        })
}
