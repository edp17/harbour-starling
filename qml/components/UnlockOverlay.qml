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

    property string title: qsTr("Locked")
    property string message: qsTr("Authenticate to access your Starling data.")
    property bool busy: false
    property string buttonText: qsTr("Unlock")

    signal unlockRequested()

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            // swallow clicks
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
                text: root.title
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.primaryColor
            }

            Label {
                width: parent.width
                text: root.message
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: root.busy
                visible: running
                size: BusyIndicatorSize.Medium
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.buttonText
                enabled: !root.busy
                onClicked: root.unlockRequested()
            }
        }
    }
}
