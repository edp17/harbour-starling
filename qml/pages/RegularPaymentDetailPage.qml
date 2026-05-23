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
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.12)

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
                text: page.isDirectDebit ? qsTr("Mandate") : qsTr("Destination")
            }

            RegularPaymentDetailSection {
                fields: page.isDirectDebit ? [
                    page.field(qsTr("Source"), page.payment.source),
                    page.field(qsTr("Originator"), page.payment.originatorName),
                    page.field(qsTr("Originator UID"), page.payment.originatorUid),
                    page.field(qsTr("Merchant UID"), page.payment.merchantUid)
                ] : [
                    page.field(qsTr("Name"), page.standingOrderPayeeName()),
                    page.field(qsTr("Account number"), page.standingOrderAccount() ? page.standingOrderAccount().accountIdentifier : ""),
                    page.field(qsTr("Sort code"), page.standingOrderAccount() ? page.standingOrderAccount().bankIdentifier : ""),
                    page.field(qsTr("Account description"), page.standingOrderAccount() ? page.standingOrderAccount().description : ""),
                    page.field(qsTr("Reference"), page.payment.reference),
                    page.field(qsTr("Spending category"), page.payment.spendingCategory)
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
                    page.field(qsTr("Interval"), page.payment.interval),
                    page.field(qsTr("Start date"), page.payment.startDate),
                    page.field(qsTr("Next payment"), page.payment.nextDate),
                    page.field(qsTr("Count"), page.payment.count),
                    page.field(qsTr("Until date"), page.payment.untilDate),
                    page.field(qsTr("Updated"), page.payment.updatedAt),
                    page.field(qsTr("Cancelled at"), page.payment.cancelledAt)
                ]
            }
        }

        VerticalScrollDecorator {}
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
