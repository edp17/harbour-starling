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

MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    hoverEnabled: false
    preventStealing: false
    propagateComposedEvents: true

    onPressed: {
        starlingClient.registerUserActivity()
        mouse.accepted = false
    }

    onReleased: {
        mouse.accepted = false
    }

    onPositionChanged: {
        mouse.accepted = false
    }

    onClicked: {
        mouse.accepted = false
    }

    onPressAndHold: {
        mouse.accepted = false
    }
}
