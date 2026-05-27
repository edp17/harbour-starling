/*
    Copyright (C) 2026 edp17 and chatGPT

    This file is part of harbour-starling.

    The harbour-starling is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The harbour-starling is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the harbour-starling. If not, see <http://www.gnu.org/licenses/>.
*/
import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: page

    property bool lockedState: starlingClient.locked
    property bool hasMainToken: starlingClient.token.length > 0
    property bool hasPayeeWriteToken: starlingClient.payeeWriteToken.length > 0
    property bool isOnline: starlingClient.online
    property bool readyForContent: !starlingClient.locked && hasMainToken
    property bool hasPayeesLoaded: starlingClient.payees.length > 0

    function refreshIfNeeded() {
        if (page.readyForContent
                && starlingClient.online
                && page.status === PageStatus.Active
                && starlingClient.payees.length === 0
                && !starlingClient.busy) {
            starlingClient.refreshPayees()
        }
    }

    SilicaListView {
        anchors.fill: parent
        model: page.readyForContent && page.isOnline ? starlingClient.payees : []

        PullDownMenu {
            MenuItem {
                enabled: page.readyForContent && page.hasPayeeWriteToken && page.isOnline
                visible: page.readyForContent && page.hasPayeeWriteToken && page.isOnline
                text: qsTr("Add payee")
                onClicked: pageStack.push(Qt.resolvedUrl("AddPayeePage.qml"))
            }
            MenuItem {
                enabled: page.readyForContent && page.isOnline
                visible: page.readyForContent && page.isOnline
                text: qsTr("Refresh")
                onClicked: starlingClient.refreshPayees()
            }
        }

        header: Column {
            width: parent ? parent.width : page.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Payees")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: page.width - 2 * x
                text: starlingClient.lastUpdated.length > 0
                      ? qsTr("Updated: %1").arg(starlingClient.lastUpdated)
                      : qsTr("Updated: -")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                visible: page.readyForContent && page.hasPayeeWriteToken && page.isOnline
            }
        }

        ViewPlaceholder {
            enabled: page.readyForContent
                     && page.isOnline
                     && starlingClient.payees.length === 0
                     && !starlingClient.busy
            text: qsTr("No payees loaded")
            hintText: qsTr("Pull down to refresh")
        }

        Item {
            anchors.fill: parent
            visible: !starlingClient.locked && !page.hasMainToken

            Rectangle {
                id: noPayeesAccessCard
                x: Theme.horizontalPageMargin
                y: Theme.itemSizeLarge + Theme.paddingLarge
                width: parent.width - Theme.horizontalPageMargin * 2
                height: noPayeesAccessColumn.height + Theme.paddingLarge * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.12)

                Column {
                    id: noPayeesAccessColumn
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - Theme.paddingLarge * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("No account access configured")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Open Settings to add your access token.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: !starlingClient.locked
                     && page.hasMainToken
                     && !page.isOnline

            Rectangle {
                id: offlinePayeesCard
                x: Theme.horizontalPageMargin
                y: Theme.itemSizeLarge + Theme.paddingLarge
                width: parent.width - Theme.horizontalPageMargin * 2
                height: offlinePayeesColumn.height + Theme.paddingLarge * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.12)

                Column {
                    id: offlinePayeesColumn
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - Theme.paddingLarge * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("No internet connection")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Reconnect to load payees.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        delegate: BackgroundItem {
            width: ListView.view ? ListView.view.width : parent.width
            height: payeeCard.height + Theme.paddingMedium
            enabled: page.readyForContent

            onClicked: {
                pageStack.push(Qt.resolvedUrl("PayeeDetailPage.qml"), {
                    payeeUid: modelData.payeeUid,
                    payeeName: modelData.name
                })
            }

            Rectangle {
                id: payeeCard
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: parent.width - 2 * x
                height: payeeColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.12)

                Column {
                    id: payeeColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 3 * Theme.paddingMedium - arrowIcon.width
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: modelData.name || ""
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: modelData.subtitle || ""
                        visible: (modelData.subtitle || "").length > 0
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Accounts: %1").arg(modelData.accountCount || 0)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Image {
                    id: arrowIcon
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    source: "image://theme/icon-m-right"
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    opacity: 0.7
                }
            }
        }

        VerticalScrollDecorator {}

        BusyIndicator {
            anchors.centerIn: parent
            running: starlingClient.busy && starlingClient.payees.length === 0
            visible: running
            size: BusyIndicatorSize.Large
        }
    }
    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: qsTr("Authenticate to access your Starling data.")
        busy: starlingClient.busy
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }
    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
    Component.onCompleted: refreshIfNeeded()

    onStatusChanged: {
        if (status === PageStatus.Active)
            refreshIfNeeded()
    }

    Connections {
        target: starlingClient

        function onLockedChanged() {
            page.refreshIfNeeded()
        }

        function onOnlineChanged() {
            page.refreshIfNeeded()
        }
    }
}
