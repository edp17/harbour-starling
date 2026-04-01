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
    property var sourceAccountData: ({})
    property string paymentError: ""
    property bool hasMainToken: starlingClient.token.length > 0
    property bool hasPaymentKeys: starlingClient.apiKeyId.trim().length > 0
                                  && starlingClient.privateApiKeyPem.trim().length > 0
    property bool isOnline: starlingClient.online
    property bool readyForContent: !starlingClient.locked && hasMainToken

    function valueOrEmpty(v) {
        return (v === undefined || v === null) ? "" : String(v)
    }

    function sourceValue(key, fallbackValue) {
        var v = valueOrEmpty(sourceAccountData[key])
        return v.length > 0 ? v : valueOrEmpty(fallbackValue)
    }

    function usefulStatusText() {
        var s = (starlingClient.status || "").trim()
        if (s.length === 0 || s === "Ready")
            return ""
        return s
    }

    Component.onCompleted: {
        starlingClient.clearPaymentResult()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge
        visible: readyForContent

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Make payment request")
            }

            Item {
                width: parent.width
                height: visible ? noInternetCard.height + Theme.itemSizeMedium : 0
                visible: !page.isOnline

                Rectangle {
                    id: noInternetCard
                    x: Theme.horizontalPageMargin
                    y: Theme.itemSizeSmall
                    width: parent.width - Theme.horizontalPageMargin * 2
                    height: noInternetColumn.height + Theme.paddingLarge * 2
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.22)

                    Column {
                        id: noInternetColumn
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
                            text: qsTr("Reconnect to continue with this payment.")
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
                height: visible ? noKeysCard.height + Theme.itemSizeMedium : 0
                visible: page.isOnline && !page.hasPaymentKeys

                Rectangle {
                    id: noKeysCard
                    x: Theme.horizontalPageMargin
                    y: Theme.itemSizeSmall
                    width: parent.width - Theme.horizontalPageMargin * 2
                    height: noKeysColumn.height + Theme.paddingLarge * 2
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.22)

                    Column {
                        id: noKeysColumn
                        x: Theme.paddingLarge
                        y: Theme.paddingLarge
                        width: parent.width - Theme.paddingLarge * 2
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: qsTr("Payments unavailable")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Open Settings to add your Key UID and PEM.")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: page.isOnline && page.hasPaymentKeys

                SectionHeader {
                    text: qsTr("Payee")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    text: valueOrEmpty(page.payeeName)
                    wrapMode: Text.Wrap
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                }

                SectionHeader {
                    text: qsTr("Destination account")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    text: valueOrEmpty(accountData.description).length > 0
                          ? valueOrEmpty(accountData.description)
                          : qsTr("Account")
                    wrapMode: Text.Wrap
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    visible: valueOrEmpty(accountData.accountIdentifier).length > 0
                    text: qsTr("Account number: %1").arg(valueOrEmpty(accountData.accountIdentifier))
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    visible: valueOrEmpty(accountData.bankIdentifier).length > 0
                    text: qsTr("Sort code: %1").arg(valueOrEmpty(accountData.bankIdentifier))
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                SectionHeader {
                    text: qsTr("Source account")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    text: sourceValue("accountName",
                                      starlingClient.accountName.length > 0
                                      ? starlingClient.accountName
                                      : qsTr("Primary account"))
                    wrapMode: Text.Wrap
                    color: Theme.highlightColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    visible: sourceValue("accountNumber", starlingClient.accountNumber).length > 0
                    text: qsTr("Account number: %1").arg(sourceValue("accountNumber", starlingClient.accountNumber))
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    visible: sourceValue("sortCode", starlingClient.sortCode).length > 0
                    text: qsTr("Sort code: %1").arg(sourceValue("sortCode", starlingClient.sortCode))
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                SectionHeader {
                    text: qsTr("Payment details")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    text: qsTr("Amount")
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
                TextField {
                    id: amountField
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    placeholderText: qsTr("Enter amount in GBP")
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    onTextChanged: page.paymentError = ""
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    text: qsTr("Reference")
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
                TextField {
                    id: referenceField
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    placeholderText: qsTr("Required")
                    maximumLength: 18
                    onTextChanged: page.paymentError = ""
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    text: qsTr("Maximum 18 characters for GBP/FPS payments.\n(Entered: %1 / 18 characters)").arg(referenceField.text.length)
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                }

                AppStatusMessage {
                    text: page.paymentError
                    error: true
                    compact: true
                }

                Button {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    text: qsTr("Review payment request")
                    enabled: !starlingClient.busy && page.isOnline && page.hasPaymentKeys

                    onClicked: {
                        if (!page.isOnline || !page.hasPaymentKeys)
                            return

                        page.paymentError = ""
                        starlingClient.clearPaymentResult()

                        starlingClient.preparePaymentDraft(
                            sourceValue("accountUid", starlingClient.accountUid),
                            sourceValue("categoryUid", starlingClient.categoryUid),
                            sourceValue("accountName", starlingClient.accountName),
                            sourceValue("accountNumber", starlingClient.accountNumber),
                            sourceValue("sortCode", starlingClient.sortCode),
                            page.payeeUid,
                            page.payeeName,
                            valueOrEmpty(accountData.payeeAccountUid),
                            valueOrEmpty(accountData.description),
                            valueOrEmpty(accountData.accountIdentifier),
                            valueOrEmpty(accountData.bankIdentifier),
                            amountField.text,
                            referenceField.text
                        )
                        if (starlingClient.buildPaymentPreview()) {
                            pageStack.push(Qt.resolvedUrl("PaymentConfirmPage.qml"))
                        } else {
                            page.paymentError = starlingClient.status
                        }
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
