import QtQuick 2.7
import "qrc:/NextCommon" as NextCommon

NextCommon.AboutPage {
    appName: i18n.tr("NextNews")
    appVersion: typeof nextnewsAppVersion !== "undefined" ? nextnewsAppVersion : "development"
    appDescription: "Native Ubuntu Touch client for Nextcloud News."
    logoSource: "qrc:/assets/logo.svg"
    licenseText: "NextNews is licensed under the MIT License."
    copyrightText: "Copyright (c) 2026 Etherghost"
    disclaimerText: "NextNews is not affiliated with, endorsed by, or sponsored by Nextcloud GmbH or the Nextcloud project. Nextcloud is a trademark of its respective owners."
}
