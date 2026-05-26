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
    property bool readyForContent: !starlingClient.locked

    property string activeFilterLabel: appWindow.transactionFilterLabel
    property int activeDaysBack: appWindow.transactionFilterDays
    property bool customFilterActive: appWindow.transactionFilterCustom
    property string customFromDate: appWindow.transactionFilterFrom
    property string customToDate: appWindow.transactionFilterTo

    function refreshCurrentFilter() {
        if (customFilterActive) {
            starlingClient.refreshTransactionsRange(customFromDate, customToDate)
        } else {
            starlingClient.refreshTransactions(activeDaysBack)
        }
    }

    function setDaysFilter(days) {
        activeDaysBack = days
        customFilterActive = false
        activeFilterLabel = qsTr("Last %1 days").arg(days)

        appWindow.transactionFilterLabel = activeFilterLabel
        appWindow.transactionFilterDays = activeDaysBack
        appWindow.transactionFilterCustom = false
        appWindow.transactionFilterFrom = ""
        appWindow.transactionFilterTo = ""

        starlingClient.refreshTransactions(days)
    }

    function todayIsoDate() {
        return new Date().toISOString().substring(0, 10)
    }

    function daysAgoIsoDate(days) {
        var d = new Date()
        d.setDate(d.getDate() - days)
        return d.toISOString().substring(0, 10)
    }

    function timeOnly(rawDate)
    {
        if (!rawDate)
            return ""

        var d = new Date(rawDate)
        if (isNaN(d.getTime()))
            return ""

        var hh = d.getHours()
        var mm = d.getMinutes()

        var hhText = hh < 10 ? "0" + hh : "" + hh
        var mmText = mm < 10 ? "0" + mm : "" + mm

        return hhText + ":" + mmText
    }


    function statusText() {
        var s = (starlingClient.status || "").trim()
        if (s === "" || s === "Ready")
            return ""
        return s
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: page.readyForContent ? starlingClient.transactionRows : []
        visible: !starlingClient.locked

        PullDownMenu {
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Feed export")
                onClicked: pageStack.push(Qt.resolvedUrl("FeedExportPage.qml"))
            }
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Refresh current filter")
                onClicked: page.refreshCurrentFilter()
            }
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Custom range")
                onClicked: {
                    if (page.customFromDate.length === 0)
                        page.customFromDate = page.daysAgoIsoDate(30)
                    if (page.customToDate.length === 0)
                        page.customToDate = page.todayIsoDate()
                    customRangeOverlay.open = true
                }
            }
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Last 30 days")
                onClicked: page.setDaysFilter(30)
            }
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Last 14 days")
                onClicked: page.setDaysFilter(14)
            }
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Last 7 days")
                onClicked: page.setDaysFilter(7)
            }
        }

        header: Column {
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: "Transactions"
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: filterColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.12)

                Column {
                    id: filterColumn

                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Active filter")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: page.activeFilterLabel
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        wrapMode: Text.Wrap
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !starlingClient.busy
                         && page.statusText().length > 0
                         && starlingClient.transactionRows.length === 0
                wrapMode: Text.Wrap
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.statusText()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                text: "For details, tap on the transaction card"
            }

            BusyIndicator {
                x: Theme.horizontalPageMargin
                size: BusyIndicatorSize.Medium
                running: starlingClient.busy
                visible: running
            }

            Label {
                visible: !starlingClient.busy
                         && starlingClient.transactionRows.length === 0
                         && page.statusText().length === 0
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                text: "No transactions loaded."
            }
        }

        delegate: Item {
            id: delegateRoot
            width: listView.width

            property bool isHeader: modelData && modelData.rowType === "header"
            property bool isTransaction: modelData && modelData.rowType === "transaction"
            property real innerWidth: width - 2 * Theme.horizontalPageMargin
            property real secondBlockHeight: Math.max(subtitleLabel.height, metaLabel.height)

            height: isHeader
                    ? (headerLabel.height + Theme.paddingMedium)
                    : (Theme.paddingSmall + card.height + Theme.paddingSmall)

            SectionHeader {
                id: headerLabel
                visible: delegateRoot.isHeader
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: delegateRoot.isHeader && modelData.title ? modelData.title : ""
            }

            BackgroundItem {
                id: txItem
                visible: delegateRoot.isTransaction
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: delegateRoot.innerWidth
                height: card.height

                onClicked: {
                    pageStack.push(Qt.resolvedUrl("TransactionDetailPage.qml"), {
                        transactionData: modelData
                    })
                }

                Rectangle {
                    id: card
                    width: parent.width
                    height: Theme.paddingMedium
                            + titleLabel.height
                            + Theme.paddingSmall
                            + delegateRoot.secondBlockHeight
                            + Theme.paddingMedium
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.12)
                }

                property string subtitleText: {
                    if (!delegateRoot.isTransaction)
                        return ""

                    if ((modelData.reference || "").length > 0 && modelData.reference !== modelData.title)
                        return modelData.reference

                    if ((modelData.category || "").length > 0)
                        return modelData.category

                    return ""
                }

                Label {
                    id: titleLabel
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: card.width - 2 * Theme.paddingMedium - amountLabel.width - Theme.paddingLarge
                    text: delegateRoot.isTransaction && modelData.title ? modelData.title : "-"
                    truncationMode: TruncationMode.Fade
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                    maximumLineCount: 1
                }

                Label {
                    id: amountLabel
                    anchors.right: card.right
                    anchors.rightMargin: Theme.paddingMedium
                    y: Theme.paddingMedium
                    text: delegateRoot.isTransaction && modelData.amount ? modelData.amount : "-"
                    color: delegateRoot.isTransaction && modelData.direction === "OUT"
                           ? Theme.primaryColor
                           : Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    maximumLineCount: 1
                }

                Item {
                    id: bottomRow
                    x: Theme.paddingMedium
                    y: titleLabel.y + titleLabel.height + Theme.paddingSmall
                    width: card.width - 2 * Theme.paddingMedium
                    height: delegateRoot.secondBlockHeight

                    Label {
                        id: subtitleLabel
                        width: parent.width * 0.58
                        text: txItem.subtitleText
                        visible: text.length > 0
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                        maximumLineCount: 1
                    }

                    Label {
                        id: metaLabel
                        anchors.right: parent.right
                        width: parent.width * 0.42
                        text: {
                            if (!delegateRoot.isTransaction)
                                return ""

                            var t = page.timeOnly(modelData.dateRaw)
                            var s = modelData.status || ""

                            if (t.length > 0 && s.length > 0)
                                return t + "  " + s
                            if (t.length > 0)
                                return t
                            return s
                        }
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                        maximumLineCount: 1
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
    // Trasaction custom range overlay
    TransactionCustomRangeOverlay {
        id: customRangeOverlay

        fromDate: page.customFromDate
        toDate: page.customToDate

        onAccepted: {
            page.customFromDate = fromDate
            page.customToDate = toDate
            page.customFilterActive = true
            page.activeFilterLabel = fromDate + " - " + toDate

            appWindow.transactionFilterLabel = page.activeFilterLabel
            appWindow.transactionFilterDays = page.activeDaysBack
            appWindow.transactionFilterCustom = true
            appWindow.transactionFilterFrom = fromDate
            appWindow.transactionFilterTo = toDate

            starlingClient.refreshTransactionsRange(fromDate, toDate)
        }
    }

    // Unlock overlay
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
    Component.onCompleted: {
        if (starlingClient.token.length > 0 && starlingClient.transactionRows.length === 0)
            page.setDaysFilter(14)
    }
}
