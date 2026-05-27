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
    allowedOrientations: Orientation.All

    property bool readyForContent: !starlingClient.locked
    property var transactionData: ({})
    property string titleText: transactionData && transactionData.title ? transactionData.title : "-"
    property string amountText: transactionData && transactionData.amount ? transactionData.amount : "-"
    property string referenceText: transactionData && transactionData.reference ? transactionData.reference : ""
    property string dateText: transactionData && transactionData.date ? transactionData.date : "-"
    property string rawDateText: transactionData && transactionData.dateRaw ? transactionData.dateRaw : ""
    property string statusText: transactionData && transactionData.status ? transactionData.status : "-"
    property string categoryText: transactionData && transactionData.category ? transactionData.category : "-"
    property string directionText: transactionData && transactionData.direction ? transactionData.direction : "-"
    property string currencyText: transactionData && transactionData.currency ? transactionData.currency : "-"
    property bool editingNote: false
    property bool editingCategory: false
    property var categoryOptions: [
        "GENERAL",
        "GROCERIES",
        "EATING_OUT",
        "TRANSPORT",
        "FUEL",
        "BILLS_AND_SERVICES",
        "SHOPPING",
        "ENTERTAINMENT",
        "HOLIDAYS",
        "SAVING"
    ]
    property string selectedCategory: transactionData.category || "GENERAL"
    property int saveButtonWidth: Theme.itemSizeLarge

    function canEditNote() {
        return transactionData.feedItemUid && transactionData.feedItemUid.length > 0
    }

    function canEditCategory() {
        return transactionData.feedItemUid && transactionData.feedItemUid.length > 0
    }

    function shown(value) {
        return value && String(value).length > 0 ? value : "-"
    }

    Component.onCompleted: {
        if (transactionData.feedItemUid && transactionData.feedItemUid.length > 0)
            starlingClient.refreshTransactionDetail(transactionData.feedItemUid)

        if (transactionData.feedItemUid && transactionData.feedItemUid.length > 0)
            starlingClient.refreshTransactionAttachments(transactionData.feedItemUid)

        if (transactionData.feedItemUid && transactionData.feedItemUid.length > 0)
            starlingClient.refreshTransactionReceipts(transactionData.feedItemUid)

        if (transactionData.feedItemUid && transactionData.feedItemUid.length > 0)
            starlingClient.refreshTransactionMastercardDetails(transactionData.feedItemUid)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge
        visible: !starlingClient.locked

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh transactions")
                onClicked: starlingClient.refreshTransactions(14)
            }
        }

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Transaction")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: summaryColumn.height + 2 * Theme.paddingLarge
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: summaryColumn
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - 2 * Theme.paddingLarge
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: titleText
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeLarge
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: amountText
                        color: directionText === "OUT" ? Theme.primaryColor : Theme.highlightColor
                        font.pixelSize: Theme.fontSizeHuge
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Label {
                            text: shown(dateText)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            visible: directionText.length > 0
                            text: shown(directionText)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: detailsColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: detailsColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: qsTr("Details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: qsTr("Reference")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: shown(referenceText)
                            color: Theme.primaryColor
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Column {
                            width: parent.width / 2 - Theme.paddingMedium / 2
                            spacing: Theme.paddingSmall / 2

                            Label {
                                width: parent.width
                                text: qsTr("Category")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: shown(categoryText)
                                color: Theme.primaryColor
                            }
                        }

                        Column {
                            width: parent.width / 2 - Theme.paddingMedium / 2
                            spacing: Theme.paddingSmall / 2

                            Label {
                                width: parent.width
                                text: qsTr("Status")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: shown(statusText)
                                color: Theme.primaryColor
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Column {
                            width: parent.width / 2 - Theme.paddingMedium / 2
                            spacing: Theme.paddingSmall / 2

                            Label {
                                width: parent.width
                                text: qsTr("Direction")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: shown(directionText)
                                color: Theme.primaryColor
                            }
                        }

                        Column {
                            width: parent.width / 2 - Theme.paddingMedium / 2
                            spacing: Theme.paddingSmall / 2

                            Label {
                                width: parent.width
                                text: qsTr("Currency")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: shown(currencyText)
                                color: Theme.primaryColor
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: qsTr("Raw timestamp")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: shown(rawDateText)
                            color: Theme.primaryColor
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: extraDetailColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: extraDetailColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Extra details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.transactionDetail.feedItemUid !== transactionData.feedItemUid
                        text: qsTr("Loading details...")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.transactionDetail.feedItemUid === transactionData.feedItemUid
                        text: qsTr("Source: %1").arg(starlingClient.transactionDetail.source || "-")
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.transactionDetail.feedItemUid === transactionData.feedItemUid
                               && starlingClient.transactionDetail.counterPartyType
                               && starlingClient.transactionDetail.counterPartyType.length > 0
                        text: qsTr("Counterparty type: %1").arg(starlingClient.transactionDetail.counterPartyType)
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.transactionDetail.feedItemUid === transactionData.feedItemUid
                               && starlingClient.transactionDetail.settlementTime
                               && starlingClient.transactionDetail.settlementTime.length > 0
                        text: qsTr("Settled: %1").arg(starlingClient.transactionDetail.settlementTime)
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.transactionDetail.feedItemUid === transactionData.feedItemUid
                        text: qsTr("Updated: %1").arg(starlingClient.transactionDetail.updatedAt || "-")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: attachmentsColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: attachmentsColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Attachments")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.busy && starlingClient.transactionAttachments.length === 0
                        text: qsTr("Loading attachments...")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: !starlingClient.busy && starlingClient.transactionAttachments.length === 0
                        text: qsTr("No attachments found.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Repeater {
                        model: starlingClient.transactionAttachments

                        Column {
                            width: parent.width
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: modelData.name && modelData.name.length > 0
                                      ? modelData.name
                                      : qsTr("Attachment")
                                color: Theme.primaryColor
                                font.bold: true
                                wrapMode: Text.Wrap
                            }

                            Label {
                                width: parent.width
                                visible: modelData.contentType && modelData.contentType.length > 0
                                text: modelData.contentType
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.Wrap
                            }

                            Label {
                                width: parent.width
                                visible: modelData.createdAt && modelData.createdAt.length > 0
                                text: modelData.createdAt
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                wrapMode: Text.Wrap
                            }

                            Button {
                                width: parent.width
                                enabled: !starlingClient.busy
                                         && transactionData.feedItemUid
                                         && transactionData.feedItemUid.length > 0
                                         && modelData.feedItemAttachmentUid
                                         && modelData.feedItemAttachmentUid.length > 0
                                text: qsTr("Download")
                                onClicked: starlingClient.downloadTransactionAttachment(
                                               transactionData.feedItemUid,
                                               modelData.feedItemAttachmentUid,
                                               modelData.name || qsTr("starling-attachment"))
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.lastAttachmentPath.length > 0
                        text: qsTr("Last saved:\n%1").arg(starlingClient.lastAttachmentPath)
                        color: Theme.secondaryColor
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: receiptsColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: receiptsColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Receipts")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.busy && starlingClient.transactionReceipts.length === 0
                        text: qsTr("Loading receipts...")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: !starlingClient.busy && starlingClient.transactionReceipts.length === 0
                        text: qsTr("No receipts found.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Repeater {
                        model: starlingClient.transactionReceipts

                        Column {
                            width: parent.width
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: modelData.name && modelData.name.length > 0
                                      ? modelData.name
                                      : qsTr("Receipt")
                                color: Theme.primaryColor
                                font.bold: true
                                wrapMode: Text.Wrap
                            }

                            Label {
                                width: parent.width
                                visible: modelData.createdAt && modelData.createdAt.length > 0
                                text: modelData.createdAt
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: mastercardColumn.height + 2 * Theme.paddingMedium

                visible: starlingClient.transactionMastercardDetails.feedItemUid === transactionData.feedItemUid
                         && ((starlingClient.transactionMastercardDetails.merchantName || "").length > 0
                             || (starlingClient.transactionMastercardDetails.merchantCategory || "").length > 0
                             || (starlingClient.transactionMastercardDetails.cardLastFour || "").length > 0)
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: mastercardColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Card transaction details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }

                    Label {
                        width: parent.width
                        visible: (starlingClient.transactionMastercardDetails.merchantName || "").length > 0
                        text: qsTr("Merchant: %1").arg(starlingClient.transactionMastercardDetails.merchantName)
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: (starlingClient.transactionMastercardDetails.merchantCategory || "").length > 0
                        text: qsTr("Category: %1").arg(starlingClient.transactionMastercardDetails.merchantCategory)
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: (starlingClient.transactionMastercardDetails.merchantCategoryCode || "").length > 0
                        text: qsTr("Category code: %1").arg(starlingClient.transactionMastercardDetails.merchantCategoryCode)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: (starlingClient.transactionMastercardDetails.merchantCity || "").length > 0 || (starlingClient.transactionMastercardDetails.merchantCountry || "").length > 0
                        text: qsTr("Location: %1 %2")
                              .arg(starlingClient.transactionMastercardDetails.merchantCity || "")
                              .arg(starlingClient.transactionMastercardDetails.merchantCountry || "")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: (starlingClient.transactionMastercardDetails.cardLastFour || "").length > 0
                        text: qsTr("Card: **** %1").arg(starlingClient.transactionMastercardDetails.cardLastFour)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: (starlingClient.transactionMastercardDetails.wallet || "").length > 0
                        text: qsTr("Wallet: %1").arg(starlingClient.transactionMastercardDetails.wallet)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: (starlingClient.transactionMastercardDetails.posEntryMode || "").length > 0
                        text: qsTr("Entry mode: %1").arg(starlingClient.transactionMastercardDetails.posEntryMode)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: categoryColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: categoryColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: qsTr("Category")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: !page.editingCategory
                        text: transactionData.category || qsTr("No category")
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        TextSwitch {
                            id: editCategorySwitch
                            width: parent.width - page.saveButtonWidth - Theme.paddingSmall
                            text: qsTr("Edit category")
                            checked: page.editingCategory
                            enabled: page.canEditCategory() && !starlingClient.busy
                            onCheckedChanged: {
                                page.editingCategory = checked
                                if (checked)
                                    page.selectedCategory = transactionData.category || "GENERAL"
                            }
                        }

                        Button {
                            id: saveCategoryButton
                            width: page.saveButtonWidth
                            visible: page.editingCategory
                            enabled: page.canEditCategory() && !starlingClient.busy
                            text: qsTr("Save")
                            onClicked: starlingClient.updateTransactionCategory(transactionData.feedItemUid,
                                                                                page.selectedCategory)
                        }
                    }

                    ComboBox {
                        id: categoryCombo
                        width: parent.width
                        visible: page.editingCategory
                        label: qsTr("Spending category")
                        currentIndex: Math.max(0, page.categoryOptions.indexOf(page.selectedCategory))

                        menu: ContextMenu {
                            Repeater {
                                model: page.categoryOptions

                                delegate: MenuItem {
                                    text: modelData
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < page.categoryOptions.length)
                                page.selectedCategory = page.categoryOptions[currentIndex]
                        }
                    }

                    Label {
                        width: parent.width
                        visible: !page.canEditCategory()
                        text: qsTr("This transaction cannot be edited because its feed item ID is missing.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: noteColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: noteColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: qsTr("Note")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: !page.editingNote && transactionData.userNote && transactionData.userNote.length > 0
                        text: transactionData.userNote
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        TextSwitch {
                            id: editNoteSwitch
                            width: parent.width - page.saveButtonWidth - Theme.paddingSmall
                            text: qsTr("Edit note")
                            checked: page.editingNote
                            enabled: page.canEditNote() && !starlingClient.busy
                            onCheckedChanged: {
                                page.editingNote = checked
                                if (checked)
                                    noteField.text = transactionData.userNote || ""
                            }
                        }

                        Button {
                            id: saveNoteButton
                            width: page.saveButtonWidth
                            visible: page.editingNote
                            enabled: page.canEditNote() && !starlingClient.busy
                            text: qsTr("Save")
                            onClicked: starlingClient.updateTransactionNote(transactionData.feedItemUid,
                                                                            noteField.text)
                        }
                    }

                    TextArea {
                        id: noteField
                        width: parent.width
                        visible: page.editingNote
                        label: qsTr("Transaction note")
                        placeholderText: qsTr("Add a note...")
                        text: transactionData.userNote || ""
                        enabled: page.canEditNote() && !starlingClient.busy
                    }

                    Label {
                        width: parent.width
                        visible: !page.canEditNote()
                        text: qsTr("This transaction cannot be edited because its feed item ID is missing.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }
        }
    }

    Connections {
        target: starlingClient

        onTransactionNoteUpdated: {
            if (feedItemUid === transactionData.feedItemUid) {
                var updated = transactionData
                updated.userNote = note
                transactionData = updated
                noteField.text = note
                page.editingNote = false
                editNoteSwitch.checked = false
            }
        }

        onTransactionCategoryUpdated: {
            if (feedItemUid === transactionData.feedItemUid) {
                var updated = transactionData
                updated.category = category
                transactionData = updated
                page.selectedCategory = category
                page.editingCategory = false
                editCategorySwitch.checked = false
            }
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
}
