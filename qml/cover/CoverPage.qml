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

CoverBackground {
    id: cover

    // Unlocked content
    Column {
        anchors.fill: parent
        anchors.margins: Theme.paddingMedium
        spacing: Theme.paddingSmall
        visible: !starlingClient.locked
        enabled: visible

        Row {
            width: parent.width
            spacing: Theme.paddingSmall

            Image {
                source: "file:///usr/share/icons/hicolor/172x172/apps/harbour-starling.png"
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                fillMode: Image.PreserveAspectFit
            }

            Label {
                width: parent.width - Theme.iconSizeSmall - Theme.paddingSmall
                text: "Starling Bank"
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                truncationMode: TruncationMode.Fade
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item {
            width: 1
            height: Theme.paddingMedium
        }

        Label {
            width: parent.width
            text: qsTr("Available balance")
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeExtraSmall * 0.9
            wrapMode: Text.Wrap
        }

        Label {
            width: parent.width
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeExtraSmall
            wrapMode: Text.Wrap
            textFormat: Text.RichText
            text: {
                var value = starlingClient.availableBalance.length > 0
                        ? starlingClient.availableBalance
                        : "-"
                var firstSpace = value.indexOf(" ")
                if (firstSpace > 0) {
                    var currency = value.substring(0, firstSpace)
                    var amount = value.substring(firstSpace + 1)
                    return "<span style='font-size:" + Math.round(Theme.fontSizeExtraSmall * 0.9) + "px;'>" +
                            currency + "</span> " +
                            "<span style='font-size:" + Math.round(Theme.fontSizeExtraSmall * 0.9) + "px;'>" +
                            amount + "</span>"
                }
                return value
            }
        }

        Rectangle {
            width: parent.width
            height: summaryColumn.height + Theme.paddingMedium * 2
            radius: Theme.paddingSmall
            color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
            border.width: 2
            border.color: Theme.rgba(Theme.highlightColor, 0.8)

            Column {
                id: summaryColumn
                x: Theme.paddingMedium
                y: Theme.paddingMedium
                width: parent.width - Theme.paddingMedium * 2
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: qsTr("Cleared balance")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    wrapMode: Text.Wrap
                }

                Label {
                    width: parent.width
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    wrapMode: Text.Wrap
                    textFormat: Text.RichText
                    text: {
                        var value = starlingClient.clearedBalance.length > 0
                                ? starlingClient.clearedBalance
                                : "-"
                        var firstSpace = value.indexOf(" ")
                        if (firstSpace > 0) {
                            var currency = value.substring(0, firstSpace)
                            var amount = value.substring(firstSpace + 1)
                            return "<span style='font-size:" + Math.round(Theme.fontSizeExtraSmall * 0.9) + "px;'>" +
                                    currency + "</span> " +
                                    "<span style='font-size:" + Math.round(Theme.fontSizeMedium * 1.15) + "px;'>" +
                                    amount + "</span>"
                        }
                        return value
                    }
                    truncationMode: TruncationMode.Fade
                }
            }
        }

        Item {
            width: 1
            height: Theme.paddingSmall / 2
        }

        Column {
            width: parent.width
            spacing: Theme.paddingSmall / 2

            Label {
                width: parent.width
                textFormat: Text.RichText

                text: {
                    if (starlingClient.cards.length > 0) {
                        var card = starlingClient.cards[0]
                        var title = card.title || ""
                        var digits = title.replace(/\D/g, "")
                        var last4 = digits.length >= 4 ? digits.slice(-4) : ""

                        var prefix = last4.length === 4
                                ? qsTr("Card-%1").arg(last4)
                                : qsTr("Card")

                        var status = card.enabled === true ? qsTr("Active") : qsTr("FROZEN")
                        var statusColor = card.enabled === true ? "#2fb344" : "#d4a017"

                        return "<span style='color:" + Theme.primaryColor + ";'>" + prefix + "</span>" +
                               "<span style='color:" + Theme.secondaryColor + ";'>: </span>" +
                               "<span style='color:" + statusColor + "; font-weight:bold;'>" + status + "</span>"
                    }

                    return "<span style='color:" + Theme.secondaryColor + ";'>" + qsTr("Card: -") + "</span>"
                }

                font.pixelSize: Theme.fontSizeExtraSmall * 0.9
                truncationMode: TruncationMode.Fade
            }

            Item {
                width: 1
                height: Theme.paddingSmall / 2
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: starlingClient.busy
                      ? qsTr("Refreshing...")
                      : (starlingClient.lastUpdated.length > 0
                         ? starlingClient.lastUpdated
                         : qsTr("Ready"))
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall * 0.75
                maximumLineCount: 2
                truncationMode: TruncationMode.Fade
            }
        }
    }

    // Locked content
    Item {
        anchors.fill: parent
        visible: starlingClient.locked
        enabled: visible

        Column {
            width: parent.width - Theme.paddingLarge * 2
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Image {
                source: "file:///usr/share/icons/hicolor/172x172/apps/harbour-starling.png"
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                fillMode: Image.PreserveAspectFit
            }

            Label {
                width: parent.width
                text: "Starling Bank"
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                width: 1
                height: Theme.paddingSmall / 2
            }

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "image://theme/icon-m-device-lock"
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                highlighted: true
            }

            Label {
                width: parent.width
                text: qsTr("App locked")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("Open app to unlock")
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
