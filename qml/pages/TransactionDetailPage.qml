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
import Sailfish.Pickers 1.0
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
    property bool uploadingAttachment: false
    property string attachmentError: ""
    property bool attachmentsRequested: false
    property int selectedAttachmentIndex: 0

    function selectedAttachment() {
        if (starlingClient.transactionAttachments.length === 0)
            return null

        if (selectedAttachmentIndex < 0
                || selectedAttachmentIndex >= starlingClient.transactionAttachments.length)
            return starlingClient.transactionAttachments[0]

        return starlingClient.transactionAttachments[selectedAttachmentIndex]
    }

    function attachmentDisplayName(attachment, idx) {
        if (attachment && attachment.name && attachment.name.length > 0)
            return attachment.name

        return qsTr("Attachment %1").arg(idx + 1)
    }

    function allowedAttachmentPath(path) {
        var p = (path || "").toString().toLowerCase()

        return p.length >= 4
                && (p.slice(-4) === ".jpg"
                    || p.slice(-5) === ".jpeg"
                    || p.slice(-4) === ".png"
                    || p.slice(-4) === ".pdf")
    }

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
            page.attachmentsRequested = true
            starlingClient.refreshTransactionAttachments(transactionData.feedItemUid)

        if (transactionData.feedItemUid && transactionData.feedItemUid.length > 0)
            starlingClient.refreshTransactionReceipts(transactionData.feedItemUid)

        if (transactionData.feedItemUid && transactionData.feedItemUid.length > 0)
            starlingClient.refreshTransactionMastercardDetails(transactionData.feedItemUid)
    }

    Component.onDestruction: {
        starlingClient.clearLastAttachmentPath()
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

                    Item {
                        width: parent.width
                        height: Math.max(attachmentsTitleLabel.height, uploadAttachmentSwitch.height)

                        Label {
                            id: attachmentsTitleLabel
                            anchors.left: parent.left
                            anchors.right: uploadAttachmentSwitch.left
                            anchors.rightMargin: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter

                            text: qsTr("Attachments")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            truncationMode: TruncationMode.Fade
                        }

                        TextSwitch {
                            id: uploadAttachmentSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            width: Theme.itemSizeHuge * 1.4
                            text: qsTr("Upload")
                            checked: page.uploadingAttachment
                            enabled: !starlingClient.busy

                            onCheckedChanged: {
                                page.uploadingAttachment = checked

                                if (!checked)
                                    page.attachmentError = ""
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: page.uploadingAttachment
                        text: qsTr("Only images and PDF files can be uploaded.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Button {
                        width: parent.width
                        visible: page.uploadingAttachment
                        enabled: !starlingClient.busy
                        text: qsTr("Choose file")
                        onClicked: pageStack.push(attachmentFilePickerComponent)
                    }

                    TextField {
                        id: attachmentPathField
                        width: parent.width
                        visible: page.uploadingAttachment
                        label: qsTr("Attachment file path")
                        placeholderText: qsTr("/home/defaultuser/Documents/receipt.jpg")
                        enabled: !starlingClient.busy
                        onTextChanged: page.attachmentError = ""
                    }

                    Button {
                        width: parent.width
                        visible: page.uploadingAttachment
                        enabled: !starlingClient.busy
                                 && transactionData.feedItemUid
                                 && transactionData.feedItemUid.length > 0
                                 && attachmentPathField.text.trim().length > 0
                        text: qsTr("Upload attachment")
                        onClicked: {
                            page.attachmentError = ""

                            var path = attachmentPathField.text.trim()

                            if (!page.allowedAttachmentPath(path)) {
                                page.attachmentError = qsTr("Please choose an image or PDF file.")
                                return
                            }

                            if (!starlingClient.localFileExists(path)) {
                                page.attachmentError = qsTr("File not found.")
                                return
                            }

                            starlingClient.uploadTransactionAttachment(transactionData.feedItemUid, path)
                        }
                    }

                    Label {
                        width: parent.width
                        visible: page.attachmentError.length > 0
                        text: page.attachmentError
                        color: Theme.errorColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: page.attachmentsRequested
                                 && starlingClient.busy
                                 && starlingClient.transactionAttachments.length === 0
                        text: qsTr("Loading attachments...")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: page.attachmentsRequested
                                 && !starlingClient.busy
                                 && starlingClient.transactionAttachments.length === 0
                        text: qsTr("No attachments found.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    ComboBox {
                        id: attachmentCombo
                        width: parent.width
                        visible: starlingClient.transactionAttachments.length > 0
                        label: qsTr("Attachment")
                        currentIndex: page.selectedAttachmentIndex

                        menu: ContextMenu {
                            Repeater {
                                model: starlingClient.transactionAttachments

                                delegate: MenuItem {
                                    text: page.attachmentDisplayName(modelData, index)
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            page.selectedAttachmentIndex = currentIndex
                        }
                    }

                    Label {
                        width: parent.width
                        visible: page.selectedAttachment() !== null
                                 && ((page.selectedAttachment().contentType || "").length > 0)
                        text: page.selectedAttachment() !== null
                              ? page.selectedAttachment().contentType
                              : ""
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: page.selectedAttachment() !== null
                                 && ((page.selectedAttachment().createdAt || "").length > 0)
                        text: page.selectedAttachment() !== null
                              ? page.selectedAttachment().createdAt
                              : ""
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        wrapMode: Text.Wrap
                    }

                    Button {
                        width: parent.width
                        visible: starlingClient.transactionAttachments.length > 0
                        enabled: !starlingClient.busy
                                 && transactionData.feedItemUid
                                 && transactionData.feedItemUid.length > 0
                                 && page.selectedAttachment()
                                 && page.selectedAttachment().feedItemAttachmentUid
                                 && page.selectedAttachment().feedItemAttachmentUid.length > 0
                        text: qsTr("Download selected attachment")
                        onClicked: {
                            var attachment = page.selectedAttachment()
                            starlingClient.downloadTransactionAttachment(
                                        transactionData.feedItemUid,
                                        attachment.feedItemAttachmentUid,
                                        page.attachmentDisplayName(attachment, page.selectedAttachmentIndex))
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

                    Item {
                        width: parent.width
                        height: Math.max(categoryTitleLabel.height, editCategorySwitch.height)

                        Label {
                            id: categoryTitleLabel
                            anchors.left: parent.left
                            anchors.right: editCategorySwitch.left
                            anchors.rightMargin: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter

                            text: qsTr("Category")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            truncationMode: TruncationMode.Fade
                        }

                        TextSwitch {
                            id: editCategorySwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            width: Theme.itemSizeHuge * 1.2
                            text: qsTr("Edit")
                            checked: page.editingCategory
                            enabled: page.canEditCategory() && !starlingClient.busy

                            onCheckedChanged: {
                                page.editingCategory = checked
                                if (checked)
                                    page.selectedCategory = transactionData.category || "GENERAL"
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: !page.editingCategory
                        text: transactionData.category || qsTr("No category")
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
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

                    Button {
                        id: saveCategoryButton
                        width: parent.width
                        visible: page.editingCategory
                        enabled: page.canEditCategory() && !starlingClient.busy
                        text: qsTr("Save new category")
                        onClicked: starlingClient.updateTransactionCategory(transactionData.feedItemUid,
                                                                            page.selectedCategory)
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

                    Item {
                        width: parent.width
                        height: Math.max(noteTitleLabel.height, editNoteSwitch.height)

                        Label {
                            id: noteTitleLabel
                            anchors.left: parent.left
                            anchors.right: editNoteSwitch.left
                            anchors.rightMargin: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter

                            text: qsTr("Note")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            truncationMode: TruncationMode.Fade
                        }

                        TextSwitch {
                            id: editNoteSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            width: Theme.itemSizeHuge * 1.2
                            text: qsTr("Edit")
                            checked: page.editingNote
                            enabled: page.canEditNote() && !starlingClient.busy

                            onCheckedChanged: {
                                page.editingNote = checked
                                if (checked)
                                    noteField.text = transactionData.userNote || ""
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: !page.editingNote && transactionData.userNote && transactionData.userNote.length > 0
                        text: transactionData.userNote
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
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

                    Button {
                        id: saveNoteButton
                        width: parent.width
                        visible: page.editingNote
                        enabled: page.canEditNote() && !starlingClient.busy
                        text: qsTr("Save new note")
                        onClicked: starlingClient.updateTransactionNote(transactionData.feedItemUid,
                                                                        noteField.text)
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

    Component {
        id: attachmentFilePickerComponent

        FilePickerPage {
            title: qsTr("Select attachment")
            nameFilters: [
                "*.jpg",
                "*.jpeg",
                "*.png",
                "*.pdf"
            ]

            onSelectedContentPropertiesChanged: {
                if (selectedContentProperties && selectedContentProperties.filePath) {
                    attachmentPathField.text = selectedContentProperties.filePath
                    page.attachmentError = ""
                    page.uploadingAttachment = true
                    uploadAttachmentSwitch.checked = true
                }
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

        onTransactionAttachmentUploaded: {
            if (feedItemUid === transactionData.feedItemUid) {
                page.uploadingAttachment = false
                uploadAttachmentSwitch.checked = false
                attachmentPathField.text = ""
                page.attachmentError = ""
            }
        }

        onTransactionAttachmentsChanged: {
            page.selectedAttachmentIndex = 0
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
