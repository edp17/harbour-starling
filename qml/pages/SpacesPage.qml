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
                onClicked: starlingClient.refreshSpaces()
            }
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Create savings goal")
                onClicked: pageStack.push(Qt.resolvedUrl("CreateSavingsGoalPage.qml"))
            }
            MenuItem {
                enabled: page.readyForContent
                visible: page.readyForContent
                text: qsTr("Round-up")
                onClicked: pageStack.push(Qt.resolvedUrl("RoundUpPage.qml"))
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Spaces")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: starlingClient.locked
                text: qsTr("Unlock the app to view spaces.")
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

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.readyForContent && starlingClient.spaces.length === 0
                text: starlingClient.busy ? qsTr("Loading spaces...")
                                          : qsTr("No spaces found.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }

            Repeater {
                model: page.readyForContent ? starlingClient.spaces : []

                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    height: spaceColumn.height + 2 * Theme.paddingMedium

                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.12)

                    Column {
                        id: spaceColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 3 * Theme.paddingMedium - Theme.iconSizeMedium
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: modelData.name || qsTr("Space")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width
                            text: modelData.balance || "-"
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                        }

                        Label {
                            width: parent.width
                            visible: modelData.target && modelData.target.length > 0
                            text: qsTr("Target: %1").arg(modelData.target)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            visible: modelData.type && modelData.type.length > 0
                            text: modelData.type
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }

                    Image {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-right"
                        opacity: 0.65
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: pageStack.push(Qt.resolvedUrl("SpaceDetailPage.qml"), {
                            space: modelData
                        })
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !starlingClient.locked && starlingClient.status.length > 0
                text: starlingClient.status
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        if (page.readyForContent)
            starlingClient.refreshSpaces()
    }

    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: qsTr("Authenticate to view spaces.")
        busy: starlingClient.busy
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
