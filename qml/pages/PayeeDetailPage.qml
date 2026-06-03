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

    property string payeeUid: ""
    property string payeeName: ""
    property var payee: starlingClient.payeeDetail
    property bool deleting: false
    property bool editMode: false

    property string editPayeeName: ""
    property string editFirstName: ""
    property string editMiddleName: ""
    property string editLastName: ""
    property bool showConsentOverlay: false
    property bool hasMainToken: starlingClient.token.length > 0
    property bool hasPayeeWriteToken: starlingClient.payeeWriteToken.length > 0
    property bool readyForContent: !starlingClient.locked && hasMainToken
    property bool hasPaymentKeys: starlingClient.apiKeyId.length > 0
                                   && starlingClient.privateApiKeyPem.length > 0
    property bool isOnline: starlingClient.online
    property bool payeeLoading: payeeUid.length > 0 && (!payee || valueOrEmpty(payee.payeeUid).length === 0)
    property bool payeeImagePreviewOpen: false

    function valueOrEmpty(v) {
        return (v === undefined || v === null) ? "" : String(v)
    }

    function hasValue(v) {
        return valueOrEmpty(v).length > 0
    }

    function yesNo(v) {
        return v ? qsTr("Yes") : qsTr("No")
    }

    function paymentSigningReady() {
        return page.hasPaymentKeys && page.isOnline
    }

    function defaultSourceAccount() {
        var rows = starlingClient.sourceAccounts || []
        for (var i = 0; i < rows.length; ++i) {
            if (rows[i].isDefault === true)
                return rows[i]
        }
        return null
    }

    function startPaymentForAccount(accountData) {
        if (!paymentSigningReady())
            return

        var source = defaultSourceAccount()
        if (source) {
            pageStack.push(Qt.resolvedUrl("PaymentPage.qml"), {
                payeeUid: page.payeeUid,
                payeeName: valueOrEmpty(payee.payeeName || page.payeeName),
                accountData: accountData,
                sourceAccountData: source
            })
        } else {
            pageStack.push(Qt.resolvedUrl("SourceAccountChooserPage.qml"), {
                payeeUid: page.payeeUid,
                payeeName: valueOrEmpty(payee.payeeName || page.payeeName),
                accountData: accountData
            })
        }
    }

    Component.onCompleted: {
        if (payeeUid.length > 0)
            starlingClient.refreshPayeeDetail(payeeUid)

        if (payeeUid && payeeUid.length > 0)
           starlingClient.refreshPayeeImage(payeeUid)

        page.editPayeeName = valueOrEmpty(payee.payeeName)
        page.editFirstName = valueOrEmpty(payee.firstName)
        page.editMiddleName = valueOrEmpty(payee.middleName)
        page.editLastName = valueOrEmpty(payee.lastName)
    }

    RemorsePopup {
        id: remorseDelete
    }

    Connections {
        target: starlingClient

        onPayeeDeleted: {
            var deletedUid = arguments[0]
            if (deletedUid === page.payeeUid) {
                page.deleting = false
                pageStack.pop()
            }
        }

        onStatusChanged: {
            if (page.editMode && starlingClient.status.indexOf("Payee updated.") !== -1) {
                page.editMode = false
                starlingClient.refreshPayeeDetail(page.payeeUid)
            }
        }

        onConsentPendingChanged: {
            if (starlingClient.consentPending) {
                page.showConsentOverlay = true
                page.editMode = false
            }
        }

        onPayeeDetailChanged: {
            if (!page.editMode) {
                page.editPayeeName = valueOrEmpty(page.payee.payeeName)
                page.editFirstName = valueOrEmpty(page.payee.firstName)
                page.editMiddleName = valueOrEmpty(page.payee.middleName)
                page.editLastName = valueOrEmpty(page.payee.lastName)
            }
        }

        onPayeeWriteTokenChanged: {
            if (!page.hasPayeeWriteToken && page.editMode)
                cancelEdit()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge
        visible: !starlingClient.locked

        PullDownMenu {
            busy: starlingClient.busy

            MenuItem {
                text: qsTr("Add account")
                visible: page.readyForContent && page.hasPayeeWriteToken
                enabled: visible && !page.editMode && !page.deleting
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("AddPayeeAccountPage.qml"), {
                        payeeUid: page.payeeUid
                    })
                }
            }

            MenuItem {
                text: qsTr("Delete payee")
                visible: page.readyForContent && page.hasPayeeWriteToken
                enabled: visible && payeeUid.length > 0 && !page.deleting
                onClicked: {
                    remorseDelete.execute(qsTr("Deleting payee"), function() {
                        page.deleting = true
                        page.payeeName = ""
                        starlingClient.deletePayee(payeeUid)
                    })
                }
            }
        }

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Payee details")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.payeeLoading
                text: qsTr("Loading payee details...")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !page.payeeLoading && page.readyForContent && !page.hasPayeeWriteToken
                text: qsTr("Editing and account changes are unavailable until a payee-write token is added in Settings.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !page.payeeLoading

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: payeeSummaryColumn.height + 2 * Theme.paddingMedium
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.15)

                    Column {
                        id: payeeSummaryColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.paddingMedium
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: qsTr("Payee")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        TextField {
                            visible: page.editMode && page.hasPayeeWriteToken && !page.deleting
                            width: parent.width
                            label: qsTr("Display name")
                            text: page.editPayeeName
                            onTextChanged: page.editPayeeName = text
                        }

                        Label {
                            visible: !page.editMode
                            width: parent.width
                            text: page.deleting ? "" : valueOrEmpty(payee.payeeName || payeeName)
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width
                            visible: hasValue(payee.payeeType)
                            text: valueOrEmpty(payee.payeeType)
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: payeeImageColumn.height + 2 * Theme.paddingMedium

                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.15)

                    Column {
                        id: payeeImageColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.paddingMedium
                        spacing: Theme.paddingMedium

                        Label {
                            width: parent.width
                            text: qsTr("Payee image")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.Wrap
                            truncationMode: TruncationMode.Fade
                        }

                        Item {
                            width: parent.width
                            height: payeeImage.visible ? payeeImage.height : 0
                            visible: starlingClient.payeeImageAvailable

                            Image {
                                id: payeeImage
                                width: Theme.itemSizeHuge * 1.4
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: starlingClient.payeeImageAvailable
                                source: starlingClient.payeeImageAvailable
                                        ? "file://" + starlingClient.payeeImagePath
                                        : ""
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                            }

                            MouseArea {
                                anchors.fill: payeeImage
                                enabled: starlingClient.payeeImageAvailable
                                onClicked: page.payeeImagePreviewOpen = true
                            }
                        }

                        Label {
                            width: parent.width
                            visible: !starlingClient.payeeImageAvailable
                            text: qsTr("No payee image found.")
                            color: Theme.secondaryColor
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
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

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium
                            visible: page.editMode || hasValue(payee.firstName) || hasValue(payee.lastName)

                            Column {
                                width: parent.width / 2 - Theme.paddingMedium / 2
                                spacing: Theme.paddingSmall / 2
                                visible: page.editMode || hasValue(payee.firstName)

                                Label {
                                    width: parent.width
                                    text: qsTr("First name")
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }

                                TextField {
                                    visible: page.editMode && !page.deleting
                                    width: parent.width
                                    text: page.editFirstName
                                    onTextChanged: page.editFirstName = text
                                }

                                Label {
                                    visible: !page.editMode && hasValue(payee.firstName)
                                    width: parent.width
                                    text: valueOrEmpty(payee.firstName)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }

                            Column {
                                width: parent.width / 2 - Theme.paddingMedium / 2
                                spacing: Theme.paddingSmall / 2
                                visible: page.editMode || hasValue(payee.lastName)

                                Label {
                                    width: parent.width
                                    text: qsTr("Last name")
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }

                                TextField {
                                    visible: page.editMode && !page.deleting
                                    width: parent.width
                                    text: page.editLastName
                                    onTextChanged: page.editLastName = text
                                }

                                Label {
                                    visible: !page.editMode && hasValue(payee.lastName)
                                    width: parent.width
                                    text: valueOrEmpty(payee.lastName)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.paddingSmall / 2
                            visible: page.editMode || hasValue(payee.middleName)

                            Label {
                                width: parent.width
                                text: qsTr("Middle name")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            TextField {
                                visible: page.editMode && !page.deleting
                                width: parent.width
                                text: page.editMiddleName
                                onTextChanged: page.editMiddleName = text
                            }

                            Label {
                                visible: !page.editMode && hasValue(payee.middleName)
                                width: parent.width
                                text: valueOrEmpty(payee.middleName)
                                wrapMode: Text.Wrap
                                color: Theme.primaryColor
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium
                            visible: payee.accountCount !== undefined || hasValue(payee.businessName)

                            Column {
                                width: parent.width / 2 - Theme.paddingMedium / 2
                                spacing: Theme.paddingSmall / 2
                                visible: payee.accountCount !== undefined

                                Label {
                                    width: parent.width
                                    text: qsTr("Account count")
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }

                                Label {
                                    width: parent.width
                                    text: valueOrEmpty(payee.accountCount)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }

                            Column {
                                width: parent.width / 2 - Theme.paddingMedium / 2
                                spacing: Theme.paddingSmall / 2
                                visible: hasValue(payee.businessName)

                                Label {
                                    width: parent.width
                                    text: qsTr("Business name")
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }

                                Label {
                                    width: parent.width
                                    text: valueOrEmpty(payee.businessName)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }
                        }
                    }
                }

                Column {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    spacing: Theme.paddingMedium
                    visible: page.editMode && page.hasPayeeWriteToken

                    Button {
                        width: parent.width
                        text: qsTr("Save changes")
                        enabled: !starlingClient.busy
                                 && editPayeeName.length > 0
                                 && editFirstName.length > 0
                                 && editLastName.length > 0

                        onClicked: {
                            starlingClient.updatePayeeNames(
                                page.payeeUid,
                                editPayeeName,
                                editFirstName,
                                editMiddleName,
                                editLastName
                            )
                            starlingClient.refreshPayeeDetail(page.payeeUid)
                        }
                    }

                    Button {
                        width: parent.width
                        text: qsTr("Cancel")
                        enabled: !starlingClient.busy
                        onClicked: cancelEdit()
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    visible: !page.payeeLoading
                             && page.readyForContent
                             && !page.isOnline
                             && (payee.accounts || []).length > 0
                    text: qsTr("No internet connection. Reconnect to continue with payments.")
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    visible: !page.payeeLoading
                             && page.readyForContent
                             && page.isOnline
                             && !page.hasPaymentKeys
                             && (payee.accounts || []).length > 0
                    text: qsTr("Payments are unavailable until signing keys are added in Settings.")
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    visible: page.paymentSigningReady() && (payee.accounts || []).length > 0
                    text: qsTr("Tap an account for details, or use the payment action on the account card.")
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Repeater {
                    model: payee.accounts || []

                    delegate: BackgroundItem {
                        width: parent ? parent.width : page.width
                        height: accountCard.height + Theme.paddingMedium

                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("PayeeAccountDetailPage.qml"), {
                                payeeUid: page.payeeUid,
                                payeeName: valueOrEmpty(payee.payeeName || page.payeeName),
                                accountData: modelData
                            })
                        }

                        Rectangle {
                            id: accountCard
                            x: Theme.horizontalPageMargin
                            y: Theme.paddingSmall
                            width: page.width - 2 * x
                            height: accountColumn.height + 2 * Theme.paddingMedium
                            radius: Theme.paddingMedium
                            color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                            border.width: 1
                            border.color: Theme.rgba(Theme.primaryColor, 0.15)

                            Column {
                                id: accountColumn
                                x: Theme.paddingMedium
                                y: Theme.paddingMedium
                                width: parent.width - 3 * Theme.paddingMedium - arrowIcon.width
                                spacing: Theme.paddingSmall

                                Label {
                                    width: parent.width
                                    text: hasValue(modelData.description)
                                          ? valueOrEmpty(modelData.description)
                                          : qsTr("Account %1").arg(index + 1)
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    truncationMode: TruncationMode.Fade
                                }

                                Label {
                                    width: parent.width
                                    text: hasValue(modelData.accountIdentifier)
                                          ? qsTr("Account number: %1").arg(valueOrEmpty(modelData.accountIdentifier))
                                          : ""
                                    visible: hasValue(modelData.accountIdentifier)
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    wrapMode: Text.Wrap
                                }

                                Label {
                                    width: parent.width
                                    text: hasValue(modelData.bankIdentifier)
                                          ? qsTr("Sort code: %1").arg(valueOrEmpty(modelData.bankIdentifier))
                                          : ""
                                    visible: hasValue(modelData.bankIdentifier)
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    wrapMode: Text.Wrap
                                }

                                Label {
                                    width: parent.width
                                    text: modelData.defaultAccount ? qsTr("Default account") : ""
                                    visible: modelData.defaultAccount === true
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Label {
                                    width: parent.width
                                    text: (modelData.lastReferences && modelData.lastReferences.length > 0)
                                          ? qsTr("Latest reference: %1").arg(valueOrEmpty(modelData.lastReferences[0]))
                                          : qsTr("No references")
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    wrapMode: Text.Wrap
                                }

                                Item {
                                    width: parent.width
                                    height: page.paymentSigningReady() ? Math.max(paymentActionLabel.implicitHeight, paymentActionIcon.implicitHeight) : 0
                                    visible: page.paymentSigningReady()

                                    Label {
                                        id: paymentActionLabel
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Make payment request")
                                        color: Theme.highlightColor
                                        font.pixelSize: Theme.fontSizeSmall
                                    }

                                    Image {
                                        id: paymentActionIcon
                                        anchors.left: paymentActionLabel.right
                                        anchors.leftMargin: Theme.paddingSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "image://theme/icon-m-send"
                                        width: Theme.iconSizeMedium * 0.8
                                        height: Theme.iconSizeMedium * 0.8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: page.startPaymentForAccount(modelData)
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
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    visible: !payee.accounts || payee.accounts.length === 0
                    text: qsTr("No accounts added for this payee yet.")
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: page.showConsentOverlay
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: {
            }
        }

        Rectangle {
            id: consentPopup
            width: Math.min(parent.width - 2 * Theme.horizontalPageMargin,
                            Theme.itemSizeLarge * 4.8)
            height: consentColumn.implicitHeight + 2 * Theme.paddingLarge
            anchors.centerIn: parent
            color: Theme.rgba("black", 0.88)
            border.color: Theme.rgba(Theme.highlightColor, 0.85)
            border.width: 2
            radius: Theme.paddingLarge
            clip: true

            Column {
                id: consentColumn
                x: Theme.paddingLarge
                y: Theme.paddingLarge
                width: parent.width - 2 * Theme.paddingLarge
                spacing: Theme.paddingMedium

                Label {
                    width: parent.width
                    text: qsTr("Approval Required")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.primaryColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    width: parent.width
                    text: starlingClient.consentMessage.length > 0
                          ? starlingClient.consentMessage
                          : qsTr("This action needs approval in the Starling app.")
                    wrapMode: Text.Wrap
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Button {
                    width: parent.width
                    text: qsTr("Understood")

                    onClicked: {
                        page.showConsentOverlay = false
                        starlingClient.dismissConsentMessage()
                    }
                }
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

    Item {
        anchors.fill: parent
        visible: page.payeeImagePreviewOpen
        z: 999

        Rectangle {
            anchors.fill: parent
            color: Theme.rgba(Theme.overlayBackgroundColor, 0.90)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: page.payeeImagePreviewOpen = false
        }

        Image {
            anchors.centerIn: parent
            width: Math.min(parent.width - 2 * Theme.horizontalPageMargin,
                            sourceSize.width > 0 ? sourceSize.width : parent.width - 2 * Theme.horizontalPageMargin)
            height: Math.min(parent.height - 2 * Theme.paddingLarge,
                             sourceSize.height > 0 ? sourceSize.height : parent.height - 2 * Theme.paddingLarge)
            source: starlingClient.payeeImageAvailable
                    ? "file://" + starlingClient.payeeImagePath
                    : ""
            fillMode: Image.PreserveAspectFit
            cache: false
        }
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
