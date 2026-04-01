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
    property var accountData: ({})
    property bool deleting: false
    property bool editMode: false
    property string editDescription: ""
    property bool showConsentOverlay: false
    property bool hasMainToken: starlingClient.token.length > 0
    property bool hasPayeeWriteToken: starlingClient.payeeWriteToken.length > 0
    property bool hasPaymentKeys: starlingClient.apiKeyId.length > 0
                                   && starlingClient.privateApiKeyPem.length > 0
    property bool isOnline: starlingClient.online
    property bool readyForContent: !starlingClient.locked && hasMainToken
    property bool accountLoading: payeeUid.length > 0 && valueOrEmpty(accountData.payeeAccountUid).length === 0

    function valueOrEmpty(v) {
        return (v === undefined || v === null) ? "" : String(v)
    }

    function hasValue(v) {
        return valueOrEmpty(v).length > 0
    }

    function yesNo(v) {
        return v ? qsTr("Yes") : qsTr("No")
    }

    RemorsePopup {
        id: remorseDelete
    }

    Connections {
        target: starlingClient

        onPayeeDetailChanged: {
            if (!page.editMode) {
                var accounts = starlingClient.payeeDetail.accounts || []
                for (var i = 0; i < accounts.length; ++i) {
                    if (valueOrEmpty(accounts[i].payeeAccountUid) === valueOrEmpty(page.accountData.payeeAccountUid)) {
                        page.accountData = accounts[i]
                        page.editDescription = valueOrEmpty(accounts[i].description)
                        break
                    }
                }
            }
        }

        onConsentPendingChanged: {
            if (starlingClient.consentPending) {
                page.showConsentOverlay = true
                page.editMode = false
            }
        }

        onPayeeWriteTokenChanged: {
            if (!page.hasPayeeWriteToken && page.editMode)
                cancelEdit()
        }

        onLockedChanged: {
            if (starlingClient.locked && page.editMode)
                cancelEdit()
        }
    }

    Component.onCompleted: {
        editDescription = valueOrEmpty(accountData.description)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge
        visible: !starlingClient.locked

        PullDownMenu {
            busy: starlingClient.busy

            MenuItem {
                text: qsTr("Make payment request")
                visible: page.readyForContent && page.isOnline && page.hasPaymentKeys
                enabled: visible
                         && hasValue(accountData.payeeAccountUid)
                         && !page.editMode
                         && !page.deleting

                onClicked: {
                    pageStack.push(Qt.resolvedUrl("PaymentPage.qml"), {
                        payeeUid: page.payeeUid,
                        payeeName: page.payeeName,
                        accountData: page.accountData
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
                title: qsTr("Payee account")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.accountLoading
                text: qsTr("Loading payee account details...")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !page.accountLoading
                         && page.readyForContent
                         && !page.isOnline
                text: qsTr("No internet connection. Reconnect to continue with this payment.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !page.accountLoading
                         && page.readyForContent
                         && page.isOnline
                         && !page.hasPaymentKeys
                text: qsTr("Payments are unavailable until signing keys are added in Settings.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !page.accountLoading

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

                        Label {
                            width: parent.width
                            text: valueOrEmpty(page.payeeName)
                            wrapMode: Text.Wrap
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeLarge
                        }

                        Label {
                            width: parent.width
                            visible: hasValue(accountData.description) && !page.editMode
                            text: valueOrEmpty(accountData.description)
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: accountDetailsColumn.height + 2 * Theme.paddingMedium
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.15)

                    Column {
                        id: accountDetailsColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.paddingMedium
                        spacing: Theme.paddingMedium

                        Label {
                            width: parent.width
                            text: qsTr("Account details")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.paddingSmall / 2
                            visible: page.editMode || hasValue(accountData.description)

                            Label {
                                width: parent.width
                                text: qsTr("Account label")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            TextField {
                                visible: page.editMode && page.hasPayeeWriteToken
                                width: parent.width
                                text: page.editDescription
                                placeholderText: qsTr("Required")
                                onTextChanged: page.editDescription = text
                            }

                            Label {
                                width: parent.width
                                visible: !page.editMode && hasValue(accountData.description)
                                text: valueOrEmpty(accountData.description)
                                wrapMode: Text.Wrap
                                color: Theme.primaryColor
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium
                            visible: hasValue(accountData.accountIdentifier) || hasValue(accountData.bankIdentifier)

                            Column {
                                width: parent.width / 2 - Theme.paddingMedium / 2
                                spacing: Theme.paddingSmall / 2
                                visible: hasValue(accountData.accountIdentifier)

                                Label {
                                    width: parent.width
                                    text: qsTr("Account number")
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }

                                Label {
                                    width: parent.width
                                    text: valueOrEmpty(accountData.accountIdentifier)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }

                            Column {
                                width: parent.width / 2 - Theme.paddingMedium / 2
                                spacing: Theme.paddingSmall / 2
                                visible: hasValue(accountData.bankIdentifier)

                                Label {
                                    width: parent.width
                                    text: qsTr("Sort code / bank identifier")
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }

                                Label {
                                    width: parent.width
                                    text: valueOrEmpty(accountData.bankIdentifier)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium
                            visible: accountData.defaultAccount !== undefined || hasValue(accountData.countryCode)

                            Column {
                                width: parent.width / 2 - Theme.paddingMedium / 2
                                spacing: Theme.paddingSmall / 2
                                visible: accountData.defaultAccount !== undefined

                                Label {
                                    width: parent.width
                                    text: qsTr("Default account")
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }

                                Label {
                                    width: parent.width
                                    text: yesNo(accountData.defaultAccount)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }

                            Column {
                                width: parent.width / 2 - Theme.paddingMedium / 2
                                spacing: Theme.paddingSmall / 2
                                visible: hasValue(accountData.countryCode)

                                Label {
                                    width: parent.width
                                    text: qsTr("Country code")
                                    color: Theme.secondaryHighlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }

                                Label {
                                    width: parent.width
                                    text: valueOrEmpty(accountData.countryCode)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.paddingSmall / 2
                            visible: accountData.lastReferences && accountData.lastReferences.length > 0

                            Label {
                                width: parent.width
                                text: qsTr("Last references")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            Repeater {
                                model: accountData.lastReferences || []

                                delegate: Label {
                                    width: accountDetailsColumn.width
                                    text: valueOrEmpty(modelData)
                                    wrapMode: Text.Wrap
                                    color: Theme.primaryColor
                                }
                            }
                        }

                        Label {
                            width: parent.width
                            text: qsTr("No references")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            visible: !accountData.lastReferences || accountData.lastReferences.length === 0
                        }
                    }
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

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
