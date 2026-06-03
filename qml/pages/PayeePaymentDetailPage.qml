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

    property var paymentData: ({})

    function valueOrDash(value) {
        return value && value.length > 0 ? value : "-"
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Payment details")
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
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: (page.paymentData.amount || "").length > 0
                        text: qsTr("Amount: %1").arg(page.valueOrDash(page.paymentData.amount))
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Reference: %1").arg(page.valueOrDash(page.paymentData.reference))
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: (page.paymentData.spendingCategory || "").length > 0
                        text: qsTr("Category: %1").arg(page.paymentData.spendingCategory)
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: (page.paymentData.status || "").length > 0
                        text: qsTr("Status: %1").arg(page.paymentData.status)
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: (page.paymentData.date || "").length > 0
                        text: qsTr("Date: %1").arg(page.valueOrDash(page.paymentData.date))
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
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
