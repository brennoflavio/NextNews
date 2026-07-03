import QtQuick 2.7
import "qrc:/NextCommon" as NextCommon

NextCommon.AccountPage {
    id: page

    property var newsController

    appName: "NextNews"
    logPrefix: "NextNews"
    appApplicationId: "nextnews.cloudsite_nextnews"
    nextcloudServiceId: "nextnews.cloudsite_nextnews_nextcloud"
    owncloudServiceId: "nextnews.cloudsite_nextnews_owncloud"

    onAccountAuthorized: function(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl) {
        if (page.newsController && page.newsController.applyAccountSelection) {
            page.newsController.applyAccountSelection(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl)
        }
    }
}
