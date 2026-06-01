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
    property bool updateRequested: false
    property var multiplierOptions: [1, 2, 5, 10]
    property int selectedSpaceIndex: -1
    property int selectedMultiplier: 0

    function selectedSpace() {
        if (selectedSpaceIndex < 0 || selectedSpaceIndex >= starlingClient.spaces.length)
            return null

        return starlingClient.spaces[selectedSpaceIndex]
    }

    function selectedSpaceName(space, index) {
        if (space && space.name && space.name.length > 0)
            return space.name

        return qsTr("Savings goal %1").arg(index + 1)
    }

    function requirePinThen(action) {
        pinActionRunner.pendingAction = action
        starlingClient.requestPinConfirmation()
    }

    function enableRoundUp() {
        var space = page.selectedSpace()

        if (!space || !space.spaceUid || space.spaceUid.length === 0)
            return

        if (page.selectedMultiplier < 1 || page.selectedMultiplier > 10)
            return

        page.updateRequested = true

        requirePinThen(function() {
            starlingClient.enableRoundUp(space.spaceUid,
                                         page.selectedMultiplier)
        })
    }

    function disableRoundUp() {
        page.updateRequested = true

        requirePinThen(function() {
            starlingClient.disableRoundUp()
        })
    }

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
                        visible: starlingClient.roundUp.active === true
                                 && ((starlingClient.roundUp.activatedAt || "").length > 0)
                        text: qsTr("Activated: %1").arg(starlingClient.roundUp.activatedAt)
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

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: enableColumn.height + 2 * Theme.paddingMedium
                visible: starlingClient.roundUpLoaded
                         && starlingClient.roundUp.active !== true

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: enableColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: qsTr("Enable round-up")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Choose which savings goal should receive your spare change.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    ComboBox {
                        id: spaceCombo
                        width: parent.width
                        label: qsTr("Savings goal")
                        enabled: starlingClient.spaces.length > 0
                        currentIndex: -1
                        value: page.selectedSpace()
                               ? page.selectedSpaceName(page.selectedSpace(), page.selectedSpaceIndex)
                               : qsTr("Choose savings goal")

                        menu: ContextMenu {
                            Repeater {
                                model: starlingClient.spaces
                                delegate: MenuItem {
                                    text: page.selectedSpaceName(modelData, index)
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            page.selectedSpaceIndex = currentIndex
                        }
                    }

                    ComboBox {
                        id: multiplierCombo
                        width: parent.width
                        label: qsTr("Multiplier")
                        currentIndex: -1
                        value: page.selectedMultiplier > 0 ? ("x" + page.selectedMultiplier) : qsTr("Choose multiplier")

                        menu: ContextMenu {
                            MenuItem { text: "x1" }
                            MenuItem { text: "x2" }
                            MenuItem { text: "x5" }
                            MenuItem { text: "x10" }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < page.multiplierOptions.length)
                                page.selectedMultiplier = page.multiplierOptions[currentIndex]
                        }
                    }

                    Button {
                        width: parent.width
                        enabled: !starlingClient.busy
                                 && page.selectedSpace() !== null
                                 && page.selectedMultiplier >= 1
                                 && page.selectedMultiplier <= 10
                        text: qsTr("Enable round-up")
                        onClicked: page.enableRoundUp()
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.spaces.length === 0
                        text: qsTr("Create a savings goal first, then enable round-up.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: disableColumn.height + 2 * Theme.paddingMedium
                visible: starlingClient.roundUpLoaded && starlingClient.roundUp.active === true

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.errorColor, 0.08)
                border.width: 1
                border.color: Theme.rgba(Theme.errorColor, 0.25)

                Column {
                    id: disableColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: qsTr("Disable round-up")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }

                    Label {
                        width: parent.width
                        text: qsTr("This stops spare change from card payments being moved into your savings goal.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Button {
                        width: parent.width
                        enabled: !starlingClient.busy
                        text: qsTr("Disable round-up")
                        onClicked: page.disableRoundUp()
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

        onRoundUpUpdated: {
            if (page.updateRequested) {
                page.updateRequested = false
            }
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
