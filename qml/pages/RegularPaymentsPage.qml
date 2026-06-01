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

    property bool readyForContent: !starlingClient.locked && starlingClient.token.length > 0

    function activeRows(rows) {
        var out = []
        for (var i = 0; i < rows.length; ++i) {
            if (rows[i].isActive === true)
                out.push(rows[i])
        }
        return out
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Refresh")
                onClicked: starlingClient.refreshRegularPayments()
            }
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Payment history")
                onClicked: pageStack.push(Qt.resolvedUrl("RegularPaymentsHistoryPage.qml"))
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Regular payments")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: starlingClient.locked
                text: qsTr("Unlock the app to view regular payments.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !starlingClient.locked && starlingClient.token.length === 0
                text: qsTr("Open Settings to add your Starling Personal Access Token.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }

            SectionHeader {
                text: qsTr("Direct Debits")
                visible: page.readyForContent
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.readyForContent
                         && page.activeRows(starlingClient.directDebitMandates).length === 0
                text: !starlingClient.regularPaymentsLoaded
                      ? qsTr("Loading Direct Debits...")
                      : qsTr("No Direct Debits found.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }

            Repeater {
                model: page.readyForContent ? page.activeRows(starlingClient.directDebitMandates) : []

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: ddColumn.height + 2 * Theme.paddingMedium

                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.12)

                    Image {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-right"
                        opacity: 0.65
                    }

                    Column {
                        id: ddColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 3 * Theme.paddingMedium - Theme.iconSizeMedium
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: modelData.title || qsTr("Direct Debit")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Reference: %1").arg(modelData.reference || "-")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Status: %1").arg(modelData.status || "-")
                            color: modelData.status === "ACTIVE" ? Theme.highlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: pageStack.push(Qt.resolvedUrl("RegularPaymentDetailPage.qml"), {
                            paymentType: "directDebit",
                            payment: modelData
                        })
                    }
                }
            }

            SectionHeader {
                text: qsTr("Standing Orders")
                visible: page.readyForContent
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.readyForContent
                         && page.activeRows(starlingClient.standingOrders).length === 0
                text: !starlingClient.regularPaymentsLoaded
                      ? qsTr("Loading Standing Orders...")
                      : qsTr("No Standing Orders found.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }

            Repeater {
                model: page.readyForContent ? page.activeRows(starlingClient.standingOrders) : []

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: soColumn.height + 2 * Theme.paddingMedium

                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.12)

                    Image {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-right"
                        opacity: 0.65
                    }

                    Column {
                        id: soColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 3 * Theme.paddingMedium - Theme.iconSizeMedium
                        spacing: Theme.paddingSmall

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Label {
                                width: parent.width - amountLabel.width - Theme.paddingMedium
                                text: modelData.title || qsTr("Standing Order")
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                id: amountLabel
                                text: modelData.amount || "-"
                                color: Theme.highlightColor
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Reference: %1").arg(modelData.reference || "-")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Next payment: %1").arg(modelData.nextDate || "-")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Status: %1").arg(modelData.status || "-")
                            color: modelData.status === "ACTIVE" ? Theme.highlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: pageStack.push(Qt.resolvedUrl("RegularPaymentDetailPage.qml"), {
                            paymentType: "standingOrder",
                            payment: modelData
                        })
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        if (page.readyForContent)
            starlingClient.refreshRegularPayments()
    }

    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: qsTr("Authenticate to view regular payments.")
        busy: starlingClient.busy
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
