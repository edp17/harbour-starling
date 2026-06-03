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
    property bool createRequested: false

    property var presetGoals: [
        qsTr("Holidays"),
        qsTr("Shopping"),
        qsTr("Bills"),
        qsTr("I deserve it"),
        qsTr("Emergency fund")
    ]

    property string selectedPresetGoal: presetGoals.length > 0 ? presetGoals[0] : ""

    function selectedGoalName() {
        if (customNameSwitch.checked)
            return nameField.text.trim()

        return selectedPresetGoal
    }

    function createGoal() {
        page.createRequested = true
        starlingClient.createSavingsGoal(page.selectedGoalName(),
                                         targetField.text.trim())
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("New savings goal")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: formColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.12)

                Column {
                    id: formColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: qsTr("Create a savings goal")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Choose a goal type, set a target amount, and Starling will create a new savings space for it.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    ComboBox {
                        id: goalCombo
                        width: parent.width
                        label: qsTr("Goal")
                        visible: !customNameSwitch.checked
                        currentIndex: 0

                        menu: ContextMenu {
                            Repeater {
                                model: page.presetGoals

                                delegate: MenuItem {
                                    text: modelData
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < page.presetGoals.length)
                                page.selectedPresetGoal = page.presetGoals[currentIndex]
                        }
                    }

                    TextSwitch {
                        id: customNameSwitch
                        width: parent.width
                        text: qsTr("Use custom goal name")
                        checked: false
                    }

                    TextField {
                        id: nameField
                        width: parent.width
                        visible: customNameSwitch.checked
                        label: qsTr("Goal name")
                        placeholderText: qsTr("My savings goal")
                        EnterKey.iconSource: "image://theme/icon-m-enter-next"
                        EnterKey.onClicked: targetField.focus = true
                    }

                    TextField {
                        id: targetField
                        width: parent.width
                        label: qsTr("Target amount")
                        placeholderText: qsTr("100.00")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                        EnterKey.onClicked: createButton.clicked()
                    }

                    Button {
                        id: createButton
                        width: parent.width
                        enabled: page.readyForContent && !starlingClient.busy
                                 && targetField.text.trim().length > 0
                                 && ((customNameSwitch.checked && nameField.text.trim().length > 0)
                                     || (!customNameSwitch.checked && page.selectedPresetGoal.length > 0))
                        text: starlingClient.busy ? qsTr("Creating...") : qsTr("Create goal")
                        onClicked: page.createGoal()
                    }
                }
            }

//            Label {
//                x: Theme.horizontalPageMargin
//                width: parent.width - 2 * x
//                visible: starlingClient.status.length > 0
//                text: starlingClient.status
//                color: Theme.secondaryColor
//                wrapMode: Text.Wrap
//                font.pixelSize: Theme.fontSizeExtraSmall
//            }
        }

        VerticalScrollDecorator {}
    }

    Connections {
        target: starlingClient

        onSavingsGoalCreated: {
            if (page.createRequested) {
                page.createRequested = false
                pageStack.pop()
            }
        }
    }

    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: qsTr("Authenticate to create a savings goal.")
        busy: starlingClient.busy
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
