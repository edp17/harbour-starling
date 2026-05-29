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

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Refresh")
                onClicked: {
                    starlingClient.refreshSpaces()
                    starlingClient.refreshRoundUp()
                }
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Round-up")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: statusColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: statusColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Round-up status")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }

                    Label {
                        width: parent.width
                        text: starlingClient.roundUp.active
                              ? qsTr("Active")
                              : qsTr("Not active")
                        color: starlingClient.roundUp.active ? Theme.highlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.roundUp.active === true
                        text: qsTr("Savings goal: %1").arg(
                                  ((starlingClient.roundUp.goalName || "").length > 0)
                                  ? starlingClient.roundUp.goalName
                                  : (starlingClient.roundUp.roundUpGoalUid || "-"))
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.roundUp.active === true
                        text: qsTr("Multiplier: x%1").arg(starlingClient.roundUp.roundUpMultiplier || 1)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.roundUp.active !== true
                        text: qsTr("Round-up automatically saves the spare change from card transactions into a savings goal.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: starlingClient.status.length > 0
                text: starlingClient.status
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        if (page.readyForContent) {
            starlingClient.refreshSpaces()
            starlingClient.refreshRoundUp()
        }
    }

    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: qsTr("Authenticate to view round-up.")
        busy: starlingClient.busy
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
