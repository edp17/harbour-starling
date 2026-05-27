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

    property string paymentType: ""
    property var payment: ({})
    property bool isDirectDebit: paymentType === "directDebit"
    property bool isStandingOrder: paymentType === "standingOrder"

    property var standingOrderPayeeDetail: starlingClient.payeeDetail

    function requirePinThen(action) {
        pinActionRunner.pendingAction = action
        starlingClient.requestPinConfirmation()
    }

    function cancelStandingOrder() {
        requirePinThen(function() {
            starlingClient.cancelStandingOrder(page.payment.paymentOrderUid)
            pageStack.pop()
        })
    }

    function cancelDirectDebit() {
        requirePinThen(function() {
            starlingClient.cancelDirectDebitMandate(page.payment.mandateUid)
            pageStack.pop()
        })
    }

    QtObject {
        id: pinActionRunner
        property var pendingAction: null
    }

    Connections {
        target: starlingClient

        onPinConfirmed: {
            if (pinActionRunner.pendingAction) {
                var action = pinActionRunner.pendingAction
                pinActionRunner.pendingAction = null
                action()
            }
        }
    }

    function standingOrderDestinationLoaded() {
        if (!page.isStandingOrder)
            return true

        if (!page.payment.payeeUid || page.payment.payeeUid.length === 0)
            return true

        return standingOrderPayeeDetail
                && standingOrderPayeeDetail.payeeUid === page.payment.payeeUid
    }

    function fieldOrLoading(label, value) {
        if (!page.standingOrderDestinationLoaded())
            return label + ": " + qsTr("Loading...")

        return page.field(label, value)
    }

    function standingOrderAccount() {
        if (!page.isStandingOrder)
            return null

        if (!standingOrderPayeeDetail
                || standingOrderPayeeDetail.payeeUid !== page.payment.payeeUid)
            return null

        var accounts = standingOrderPayeeDetail.accounts || []
        for (var i = 0; i < accounts.length; ++i) {
            if (accounts[i].payeeAccountUid === page.payment.payeeAccountUid)
                return accounts[i]
        }

        return null
    }

    function standingOrderPayeeName() {
        if (standingOrderPayeeDetail
                && standingOrderPayeeDetail.payeeUid === page.payment.payeeUid
                && standingOrderPayeeDetail.payeeName)
            return standingOrderPayeeDetail.payeeName

        return ""
    }

    function valueOrDash(value) {
        return value && value.length > 0 ? value : "-"
    }

    function isLiveStatus(status) {
        return status === "ACTIVE" || status === "LIVE"
    }

    function field(label, value) {
        return label + ": " + valueOrDash(value)
    }

    Component.onCompleted: {
        if (page.isStandingOrder && page.payment.payeeUid && page.payment.payeeUid.length > 0)
            starlingClient.refreshPayeeDetail(page.payment.payeeUid)

        if (page.isStandingOrder && page.payment.paymentOrderUid && page.payment.paymentOrderUid.length > 0)
            starlingClient.refreshStandingOrderUpcomingPayments(page.payment.paymentOrderUid)

        if (page.isStandingOrder && page.payment.paymentOrderUid && page.payment.paymentOrderUid.length > 0)
            starlingClient.refreshStandingOrderPaymentHistory(page.payment.paymentOrderUid)

        if (page.isDirectDebit && page.payment.mandateUid && page.payment.mandateUid.length > 0)
            starlingClient.refreshDirectDebitPayments(page.payment.mandateUid)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: page.isDirectDebit ? qsTr("Direct Debit") : qsTr("Standing Order")
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
                        text: page.valueOrDash(page.payment.title)
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: page.isStandingOrder
                        text: page.valueOrDash(page.payment.amount)
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Status: %1").arg(page.valueOrDash(page.payment.status))
                        color: page.isLiveStatus(page.payment.status) ? Theme.highlightColor : Theme.secondaryColor
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Reference: %1").arg(page.valueOrDash(page.payment.reference))
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            SectionHeader {
                text: page.isDirectDebit ? qsTr("Mandate") : qsTr("Paying to")
            }

            RegularPaymentDetailSection {
                fields: page.isDirectDebit ? [
                    page.field(qsTr("Source"), page.payment.source),
                    page.field(qsTr("Originator"), page.payment.originatorName),
                    page.field(qsTr("Originator UID"), page.payment.originatorUid),
                    page.field(qsTr("Merchant UID"), page.payment.merchantUid)
                ] : [
                    page.fieldOrLoading(qsTr("Name"), page.standingOrderPayeeName()),
                    page.fieldOrLoading(qsTr("Account number"), page.standingOrderAccount() ? page.standingOrderAccount().accountIdentifier : ""),
                    page.fieldOrLoading(qsTr("Sort code"), page.standingOrderAccount() ? page.standingOrderAccount().bankIdentifier : ""),
                    page.fieldOrLoading(qsTr("Account description"), page.standingOrderAccount() ? page.standingOrderAccount().description : "")
                ]
            }

            SectionHeader { text: qsTr("Schedule") }

            RegularPaymentDetailSection {
                fields: page.isDirectDebit ? [
                    page.field(qsTr("Next date"), page.payment.nextDate),
                    page.field(qsTr("Last date"), page.payment.lastDate),
                    page.field(qsTr("Last payment"), page.payment.lastPaymentAmount),
                    page.field(qsTr("Last payment date"), page.payment.lastPaymentDate),
                    page.field(qsTr("Created"), page.payment.created),
                    page.field(qsTr("Cancelled"), page.payment.cancelled)
                ] : [
                    page.field(qsTr("Frequency"), page.payment.frequency),
                    page.field(qsTr("Start date"), page.payment.startDate),
                    page.field(qsTr("Next payment"), page.payment.nextDate)
                ].concat(
                    page.payment.count && page.payment.count.length > 0
                        ? [page.field(qsTr("Ending"), qsTr("After %1 payments").arg(page.payment.count))]
                        : []
                ).concat(
                    (!page.payment.count || page.payment.count.length === 0)
                            && page.payment.untilDate && page.payment.untilDate.length > 0
                        ? [page.field(qsTr("Until date"), page.payment.untilDate)]
                        : []
                ).concat([
                    page.field(qsTr("Updated"), page.payment.updatedAt),
                    page.field(qsTr("Cancelled at"), page.payment.cancelledAt)
                ])
            }

            SectionHeader {
                text: qsTr("Upcoming payments")
                visible: page.isStandingOrder
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.isStandingOrder && starlingClient.standingOrderUpcomingPayments.length === 0
                text: starlingClient.busy
                      ? qsTr("Loading upcoming payments...")
                      : (page.payment.nextDate && page.payment.nextDate.length > 0
                         ? qsTr("Next scheduled payment: %1").arg(page.payment.nextDate)
                         : qsTr("No upcoming payments found."))
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: page.isStandingOrder ? starlingClient.standingOrderUpcomingPayments : []

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: upcomingColumn.height + 2 * Theme.paddingMedium

                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.15)

                    Column {
                        id: upcomingColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.paddingMedium
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: modelData.date || "-"
                            color: Theme.primaryColor
                            font.bold: true
                        }

                        Label {
                            width: parent.width
                            visible: modelData.amount && modelData.amount.length > 0
                            text: modelData.amount
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width
                            visible: modelData.status && modelData.status.length > 0
                            text: qsTr("Status: %1").arg(modelData.status)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Payment history")
                visible: page.isStandingOrder
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.isStandingOrder && starlingClient.standingOrderPaymentHistory.length === 0
                text: starlingClient.busy ? qsTr("Loading payment history...")
                                          : qsTr("No payment history found.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: page.isStandingOrder ? starlingClient.standingOrderPaymentHistory : []

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: historyColumn.height + 2 * Theme.paddingMedium

                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.15)

                    Column {
                        id: historyColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.paddingMedium
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: modelData.date || "-"
                            color: Theme.primaryColor
                            font.bold: true
                        }

                        Label {
                            width: parent.width
                            visible: modelData.amount && modelData.amount.length > 0
                            text: modelData.amount
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width
                            visible: modelData.reference && modelData.reference.length > 0
                            text: qsTr("Reference: %1").arg(modelData.reference)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            visible: modelData.status && modelData.status.length > 0
                            text: qsTr("Status: %1").arg(modelData.status)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Payment history")
                visible: page.isDirectDebit
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.isDirectDebit && starlingClient.directDebitPayments.length === 0
                text: starlingClient.busy ? qsTr("Loading Direct Debit payments...")
                                          : qsTr("No Direct Debit payments found.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: page.isDirectDebit ? starlingClient.directDebitPayments : []

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: ddPaymentColumn.height + 2 * Theme.paddingMedium

                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.15)

                    Column {
                        id: ddPaymentColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.paddingMedium
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: modelData.date || "-"
                            color: Theme.primaryColor
                            font.bold: true
                        }

                        Label {
                            width: parent.width
                            visible: modelData.amount && modelData.amount.length > 0
                            text: modelData.amount
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width
                            visible: modelData.reference && modelData.reference.length > 0
                            text: qsTr("Reference: %1").arg(modelData.reference)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            visible: modelData.status && modelData.status.length > 0
                            text: qsTr("Status: %1").arg(modelData.status)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Actions")
                visible: page.isLiveStatus(page.payment.status)
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: actionColumn.height + 2 * Theme.paddingMedium
                visible: page.isLiveStatus(page.payment.status)

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.errorColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.errorColor, 0.15)

                Column {
                    id: actionColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: page.isDirectDebit
                              ? qsTr("Cancelling a Direct Debit stops future payments from this mandate.")
                              : qsTr("Cancelling a Standing Order stops future scheduled payments.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Button {
                        width: parent.width
                        text: page.isDirectDebit ? qsTr("Cancel Direct Debit")
                                                  : qsTr("Cancel Standing Order")
                        onClicked: {
                            if (page.isDirectDebit)
                                page.cancelDirectDebit()
                            else
                                page.cancelStandingOrder()
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
