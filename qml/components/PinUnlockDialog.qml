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

Item {
    id: root
    anchors.fill: parent
    visible: starlingClient.pinPromptVisible
    enabled: visible
    z: 5000

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            // swallow input
        }
    }

    Rectangle {
        id: panel
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.centerIn: parent
        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor
        border.width: 2
        border.color: Theme.rgba(Theme.primaryColor, 0.65)
        height: contentColumn.height + 2 * Theme.paddingLarge

        Column {
            id: contentColumn
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: starlingClient.pinConfirmationPending ? qsTr("Approve action") : qsTr("Unlock app")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.primaryColor
            }

            Label {
                width: parent.width
                text: starlingClient.pinConfirmationPending
                      ? qsTr("Enter your app PIN to approve this action.")
                      : qsTr("Enter your app PIN to continue.")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
            }

            PasswordField {
                id: pinField
                width: parent.width
                label: qsTr("PIN")
                placeholderText: qsTr("4 to 8 digits")
                inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText

                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    if (pinField.text.length > 0) {
                        if (starlingClient.submitPin(pinField.text))
                            pinField.text = ""
                    }
                }

                onTextChanged: {
                    if (starlingClient.pinError.length > 0)
                        starlingClient.clearPinError()
                }
            }

            Label {
                width: parent.width
                visible: starlingClient.pinError.length > 0
                text: starlingClient.pinError
                color: Theme.errorColor
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - parent.spacing) / 2
                    text: qsTr("Cancel")
                    onClicked: {
                        pinField.text = ""
                        starlingClient.cancelPinPrompt()
                    }
                }

                Button {
                    width: (parent.width - parent.spacing) / 2
                    text: starlingClient.pinConfirmationPending ? qsTr("Approve") : qsTr("Unlock")
                    onClicked: {
                        if (starlingClient.submitPin(pinField.text))
                            pinField.text = ""
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            pinField.text = ""
            pinField.forceActiveFocus()
        }
    }
}
