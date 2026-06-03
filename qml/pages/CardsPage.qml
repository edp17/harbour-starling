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

    property bool hasMainToken: starlingClient.token.length > 0
    property bool isOnline: starlingClient.online
    property bool readyForContent: !starlingClient.locked && hasMainToken
    property bool hasCardsLoaded: starlingClient.cards.length > 0
    property bool hasStoredPhysicalCardData: starlingClient.hasStoredPhysicalCard()
                                             || starlingClient.hasStoredPhysicalCardCvv()
                                             || starlingClient.hasStoredPhysicalCardPin()

    function refreshIfNeeded() {
        if (page.readyForContent
                && starlingClient.online
                && page.status === PageStatus.Active
                && starlingClient.cards.length === 0
                && !starlingClient.busy) {
            starlingClient.refreshCards()
        }
    }

    function stateColor(v) { return v ? "#2fb344" : "#d4a017" }

    function activeFrozen(v) {
        if (v === "Disabled")
           v = qsTr("FROZEN")

      return v
    }

    SilicaListView {
        anchors.fill: parent
        model: page.readyForContent ? starlingClient.cards : []

        PullDownMenu {
            MenuItem {
                visible: page.readyForContent && page.isOnline
                enabled: visible
                text: qsTr("Refresh")
                onClicked: starlingClient.refreshCards()
            }
        }

        header: Column {
            width: parent ? parent.width : page.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Cards")
            }

            Item {
                width: parent.width
                height: visible ? fallbackCardRect.height + Theme.paddingMedium : 0
                visible: !starlingClient.locked
                         && page.hasMainToken
                         && !page.isOnline
                         && starlingClient.cards.length === 0
                         && page.hasStoredPhysicalCardData

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("CardDetailPage.qml"), {
                            cardData: {
                                title: qsTr("Stored physical card"),
                                subtitle: qsTr("Offline"),
                                enabled: false
                            }
                        })
                    }
                }

                Rectangle {
                    id: fallbackCardRect
                    x: Theme.horizontalPageMargin
                    y: Theme.paddingSmall
                    width: parent.width - Theme.horizontalPageMargin * 2
                    height: fallbackColumn.height + 2 * Theme.paddingMedium
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.12)

                    Column {
                        id: fallbackColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 3 * Theme.paddingMedium - fallbackArrow.width
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: qsTr("Stored physical card")
                            color: Theme.highlightColor
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeMedium
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Offline")
                            color: Theme.secondaryColor
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Stored details remain available.")
                            color: Theme.secondaryColor
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }

                    Image {
                        id: fallbackArrow
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

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: starlingClient.cards.length > 0 && page.isOnline
                text: qsTr("Manage your Starling cards and card controls.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
            }
        }

        ViewPlaceholder {
            enabled: page.readyForContent
                     && page.isOnline
                     && starlingClient.cards.length === 0
                     && !starlingClient.busy
            text: qsTr("No cards loaded")
            hintText: qsTr("Pull down to refresh")
        }

        Item {
            anchors.fill: parent
            visible: !starlingClient.locked
                     && page.hasMainToken
                     && !page.isOnline
                     && starlingClient.cards.length === 0
                     && !page.hasStoredPhysicalCardData

            Rectangle {
                x: Theme.horizontalPageMargin
                y: Theme.itemSizeLarge + Theme.paddingLarge
                width: parent.width - Theme.horizontalPageMargin * 2
                height: offlineColumn.height + Theme.paddingLarge * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.12)

                Column {
                    id: offlineColumn
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
                        text: qsTr("Reconnect to load card details.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        delegate: BackgroundItem {
            id: item
            width: ListView.view.width
            height: cardRect.height + Theme.paddingMedium
            enabled: page.readyForContent

            onClicked: {
                pageStack.push(Qt.resolvedUrl("CardDetailPage.qml"), {
                    cardData: modelData
                })
            }

            Rectangle {
                id: cardRect
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: parent.width - 2 * x
                height: contentColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: contentColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 3 * Theme.paddingMedium - arrowIcon.width
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: modelData.title || qsTr("Card")
                        color: Theme.highlightColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeMedium
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: page.activeFrozen(modelData.subtitle)
                        color: page.stateColor(modelData.enabled || false)
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        visible: text.length > 0
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Label {
                            text: qsTr("POS")
                            color: page.stateColor(modelData.posEnabled || false)
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                        Label {
                            text: qsTr("ATM")
                            color: page.stateColor(modelData.atmEnabled || false)
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                        Label {
                                                text: qsTr("Online")
                            color: page.stateColor(modelData.onlineEnabled || false)
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                        Label {
                            text: qsTr("Mobile wallet")
                                                color: page.stateColor(modelData.mobileWalletEnabled || false)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            visible: modelData.mobileWalletEnabled !== undefined
                        }
                        Label {
                            text: qsTr("Magstripe")
                            color: page.stateColor(modelData.magStripeEnabled || false)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            visible: modelData.magStripeEnabled !== undefined
                        }
                        Label {
                            text: qsTr("Gambling")
                                                color: page.stateColor(modelData.gamblingEnabled || false)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            visible: modelData.gamblingEnabled !== undefined
                        }
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
            running: starlingClient.busy && starlingClient.cards.length === 0
            visible: running
            size: BusyIndicatorSize.Large
        }
    }

    Component.onCompleted: refreshIfNeeded()

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
