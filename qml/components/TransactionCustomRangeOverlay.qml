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
    id: overlay

    property bool open: false
    property string fromDate: ""
    property string toDate: ""

    signal accepted(string fromDate, string toDate)
    signal cancelled()

    anchors.fill: parent
    visible: open
    z: 999

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.85)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            overlay.open = false
            overlay.cancelled()
        }
    }

    Rectangle {
        id: panel

        width: parent.width - 2 * Theme.horizontalPageMargin
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter

        radius: Theme.paddingMedium
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
        border.width: 1
        border.color: Theme.rgba(Theme.primaryColor, 0.18)

        height: contentColumn.height + 2 * Theme.paddingLarge

        MouseArea {
            anchors.fill: parent
            onClicked: mouse.accepted = true
        }

        Column {
            id: contentColumn

            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: qsTr("Custom transaction range")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Label {
                width: parent.width
                text: qsTr("Use YYYY-MM-DD format.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            TextField {
                id: fromField
                width: parent.width
                label: qsTr("From date")
                placeholderText: qsTr("YYYY-MM-DD")
                text: overlay.fromDate
                inputMethodHints: Qt.ImhDigitsOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: toField.focus = true
            }

            TextField {
                id: toField
                width: parent.width
                label: qsTr("To date")
                placeholderText: qsTr("YYYY-MM-DD")
                text: overlay.toDate
                inputMethodHints: Qt.ImhDigitsOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: applyButton.clicked()
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Cancel")
                    onClicked: {
                        overlay.open = false
                        overlay.cancelled()
                    }
                }

                Button {
                    id: applyButton
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Apply")
                    onClicked: {
                        overlay.fromDate = fromField.text.trim()
                        overlay.toDate = toField.text.trim()
                        overlay.open = false
                        overlay.accepted(overlay.fromDate, overlay.toDate)
                    }
                }
            }
        }
    }
}
