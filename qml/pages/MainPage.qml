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

    property bool unlockedReady: !starlingClient.locked
    property bool hasMainToken: starlingClient.token.length > 0
    property bool isOnline: starlingClient.online
    property bool hasLoadedMainData: starlingClient.accountHolderName.length > 0
                                      || starlingClient.accountName.length > 0
                                      || starlingClient.availableBalance.length > 0
                                      || starlingClient.clearedBalance.length > 0
                                      || starlingClient.recentTransactions.length > 0
    property bool readyForContent: unlockedReady && hasMainToken && isOnline
    property bool showStartupBusy: starlingClient.initializing && !hasLoadedMainData

    function welcomeName()
    {
        if (starlingClient.accountHolderName.length > 0)
            return starlingClient.accountHolderName
        if (starlingClient.accountName.length > 0)
            return starlingClient.accountName
        return "there"
    }

    function accountLine()
    {
        var number = starlingClient.accountNumber
        var sortCode = starlingClient.sortCode

        if (number.length === 0 && sortCode.length === 0)
            return "Available balance"

        return number + "  " + sortCode + "\nAvailable balance"
    }

    function todayString()
    {
        var d = new Date()
        return Qt.formatDate(d, "dddd d MMMM yyyy")
    }

    Connections {
        target: starlingClient

        function onNavigationTargetChanged() {
            if (starlingClient.navigationTarget === "Settings") {
                pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
                starlingClient.clearNavigationTarget()
                return
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Account holder details")
                visible: page.unlockedReady && page.hasMainToken
                onClicked: pageStack.push(Qt.resolvedUrl("AccountHolderPage.qml"))
            }
            MenuItem {
                text: qsTr("Account details")
                visible: page.unlockedReady && page.hasMainToken
                onClicked: pageStack.push(Qt.resolvedUrl("AccountPage.qml"))
            }
            MenuItem {
                text: qsTr("Payees")
                visible: page.unlockedReady && page.hasMainToken
                onClicked: pageStack.push(Qt.resolvedUrl("PayeesPage.qml"))
            }
            MenuItem {
                text: qsTr("Cards")
                visible: page.unlockedReady && page.hasMainToken
                onClicked: pageStack.push(Qt.resolvedUrl("CardsPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: "Refresh"
                visible: page.unlockedReady && page.hasMainToken && page.isOnline
                onClicked: starlingClient.refreshAll(14)
            }
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }

        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: "Starling Bank"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                text: "Welcome " + page.welcomeName() + "!"
                visible: page.readyForContent && page.isOnline && !page.showStartupBusy
            }

            BackgroundItem {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: balancePanel.height
                onClicked: pageStack.push(Qt.resolvedUrl("TransactionsPage.qml"))
                visible: page.readyForContent && page.isOnline && !page.showStartupBusy
                enabled: visible

                Rectangle {
                    id: balancePanel
                    width: parent.width
                    height: balanceColumn.height + 2 * Theme.paddingLarge
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.15)

                    Column {
                        id: balanceColumn
                        x: Theme.paddingLarge
                        y: Theme.paddingLarge
                        width: parent.width - 2 * Theme.paddingLarge
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: page.accountLine()
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: starlingClient.availableBalance.length > 0
                                  ? starlingClient.availableBalance
                                  : "-"
                            font.pixelSize: Theme.fontSizeHuge
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "Cleared: " + (starlingClient.clearedBalance.length > 0
                                                 ? starlingClient.clearedBalance
                                                 : "-")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
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

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                text: starlingClient.lastUpdated.length > 0
                      ? "Last updated: " + starlingClient.lastUpdated
                      : "Last updated: -"
                font.pixelSize: Theme.fontSizeExtraSmall
                visible: page.readyForContent && page.isOnline && !page.showStartupBusy
            }

            Item {
                width: parent.width
                height: page.showStartupBusy ? Theme.itemSizeHuge * 2 : 0
                visible: page.showStartupBusy

                BusyIndicator {
                    id: startupBusy
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.paddingLarge
                    size: BusyIndicatorSize.Large
                    running: page.showStartupBusy
                    visible: running
                }

                Label {
                    anchors.top: startupBusy.bottom
                    anchors.topMargin: Theme.paddingMedium
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    text: starlingClient.status.length > 0 ? starlingClient.status : "Loading account data..."
                }
            }

            Item {
                width: parent.width
                height: visible ? noPatCard.height + Theme.itemSizeMedium : 0
                visible: !starlingClient.locked && starlingClient.token.length === 0

                Rectangle {
                    id: noPatCard
                    x: Theme.horizontalPageMargin
                    y: Theme.itemSizeSmall
                    width: parent.width - Theme.horizontalPageMargin * 2
                    height: noPatColumn.height + Theme.paddingLarge * 2
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.22)

                    Column {
                        id: noPatColumn
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
                width: parent.width
                height: visible ? offlineCard.height + Theme.itemSizeMedium : 0
                visible: page.unlockedReady
                         && page.hasMainToken
                         && !page.isOnline && !page.showStartupBusy

                Rectangle {
                    id: offlineCard
                    x: Theme.horizontalPageMargin
                    y: Theme.itemSizeSmall
                    width: parent.width - Theme.horizontalPageMargin * 2
                    height: offlineColumn.height + Theme.paddingLarge * 2
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.22)

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
                            text: qsTr("Reconnect to load live account data.")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            SectionHeader {
                text: "Recent activity"
                visible: page.readyForContent && page.isOnline && !page.showStartupBusy
            }

            Column {
                width: parent.width
                spacing: 0
                visible: page.readyForContent && page.isOnline && !page.showStartupBusy

                Repeater {
                    model: starlingClient.recentTransactions

                    delegate: Item {
                        width: parent ? parent.width : page.width
                        height: card.height + Theme.paddingSmall

                        BackgroundItem {
                            x: Theme.horizontalPageMargin
                            width: parent.width - 2 * x
                            height: card.height

                            onClicked: {
                                pageStack.push(Qt.resolvedUrl("TransactionDetailPage.qml"), {
                                    transactionData: modelData
                                })
                            }

                            Rectangle {
                                id: card
                                width: parent.width
                                height: cardColumn.height + 2 * Theme.paddingMedium
                                radius: Theme.paddingMedium
                                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                                border.width: 1
                                border.color: Theme.rgba(Theme.primaryColor, 0.12)

                                Column {
                                    id: cardColumn
                                    x: Theme.paddingMedium
                                    y: Theme.paddingMedium
                                    width: parent.width - 2 * Theme.paddingMedium
                                    spacing: Theme.paddingSmall

                                    Row {
                                        width: parent.width
                                        spacing: Theme.paddingMedium

                                        Label {
                                            width: parent.width - amountLabel.width - Theme.paddingMedium
                                            text: modelData.title || "-"
                                            color: Theme.primaryColor
                                            truncationMode: TruncationMode.Fade
                                            maximumLineCount: 1
                                        }

                                        Label {
                                            id: amountLabel
                                            text: modelData.amount || "-"
                                            color: modelData.direction === "OUT"
                                                   ? Theme.primaryColor
                                                   : Theme.highlightColor
                                            horizontalAlignment: Text.AlignRight
                                            font.bold: true
                                            maximumLineCount: 1
                                        }
                                    }

                                    Label {
                                        width: parent.width
                                        text: modelData.date || ""
                                        color: Theme.secondaryColor
                                        font.pixelSize: Theme.fontSizeSmall
                                        truncationMode: TruncationMode.Fade
                                        maximumLineCount: 1
                                    }
                                }
                            }
                        }
                    }
                }

                BackgroundItem {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: moreLabel.height + Theme.paddingMedium
                    onClicked: pageStack.push(Qt.resolvedUrl("TransactionsPage.qml"))

                    Label {
                        id: moreLabel
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingSmall
                        text: "More..."
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: page.todayString()
                visible: page.readyForContent && !page.showStartupBusy
            }
        }
        VerticalScrollDecorator {}
    }

    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: starlingClient.status.length > 0
                 ? starlingClient.status
                 : qsTr("Authenticate to access your Starling data.")
        busy: starlingClient.busy
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }
    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
