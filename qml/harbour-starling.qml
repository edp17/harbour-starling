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
import "pages"
import "components"

ApplicationWindow {
    id: appWindow

    property string transactionFilterLabel: qsTr("Last 14 days")
    property int transactionFilterDays: 14
    property bool transactionFilterCustom: false
    property string transactionFilterFrom: ""
    property string transactionFilterTo: ""

    PinSetupDialog {
        anchors.fill: parent
    }

    PinUnlockDialog {
        anchors.fill: parent
    }
    initialPage: Component { MainPage {} }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: Orientation.All

    onApplicationActiveChanged: {
        if (!applicationActive
                && !starlingClient.locked
                && starlingClient.lockOnBackground) {
            starlingClient.lock()
        }
    }
}
