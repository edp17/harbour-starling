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

    property var draft: starlingClient.paymentDraft

    QtObject {
        id: paymentActionRunner
        property bool submitPending: false
    }

    function valueOrEmpty(v) {
        return (v === undefined || v === null) ? "" : String(v)
    }

    function requirePinForPayment() {
        paymentActionRunner.submitPending = true
        starlingClient.requestPinConfirmation()
    }

    Connections {
        target: starlingClient

        onPaymentSubmittedChanged: {
            if (starlingClient.paymentSubmitted)
                paymentActionRunner.submitPending = false
        }

        onPinConfirmed: {
            if (paymentActionRunner.submitPending) {
                paymentActionRunner.submitPending = false
                starlingClient.submitPreparedPayment()
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge
        visible: !starlingClient.locked

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Review payment request")
            }

            SectionHeader {
                text: qsTr("Summary")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: summaryColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: summaryColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Payee: %1").arg(valueOrEmpty(draft.payeeName))
                        wrapMode: Text.Wrap
                        color: Theme.highlightColor
                    }

                    Label {
                        width: parent.width
                        visible: valueOrEmpty(draft.accountDescription).length > 0
                        text: qsTr("Account: %1").arg(valueOrEmpty(draft.accountDescription))
                        wrapMode: Text.Wrap
                        color: Theme.primaryColor
                    }

                    Label {
                        width: parent.width
                        visible: valueOrEmpty(draft.accountIdentifier).length > 0
                        text: qsTr("Account number: %1").arg(valueOrEmpty(draft.accountIdentifier))
                        wrapMode: Text.Wrap
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: valueOrEmpty(draft.bankIdentifier).length > 0
                        text: qsTr("Sort code: %1").arg(valueOrEmpty(draft.bankIdentifier))
                        wrapMode: Text.Wrap
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Amount: %1").arg(valueOrEmpty(draft.amountDisplay))
                        wrapMode: Text.Wrap
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Reference: %1").arg(valueOrEmpty(draft.reference))
                        wrapMode: Text.Wrap
                        color: Theme.primaryColor
                    }
                }
            }

            SectionHeader {
                text: qsTr("Source account")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: valueOrEmpty(draft.sourceAccountName).length > 0
                text: valueOrEmpty(draft.sourceAccountName)
                wrapMode: Text.Wrap
                color: Theme.highlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: valueOrEmpty(draft.sourceAccountNumber).length > 0
                text: qsTr("Account number: %1").arg(valueOrEmpty(draft.sourceAccountNumber))
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: valueOrEmpty(draft.sourceSortCode).length > 0
                text: qsTr("Sort code: %1").arg(valueOrEmpty(draft.sourceSortCode))
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Button {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: starlingClient.paymentSubmitting ? qsTr("Sending...") : qsTr("Send payment request")
                enabled: !starlingClient.paymentSubmitting
                onClicked: {
                    requirePinForPayment()
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: starlingClient.paymentResultMessage.length > 0
                text: starlingClient.paymentResultMessage
                wrapMode: Text.Wrap
                color: starlingClient.paymentSubmitted ? Theme.highlightColor : Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
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
