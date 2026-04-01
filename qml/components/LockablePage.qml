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
    id: root

    // Inject your backend object here
    property var lockManager
    property bool sensitive: true

    // Content alias so child pages can place their UI here
    default property alias pageContent: contentContainer.data

    Item {
        id: contentContainer
        anchors.fill: parent
        enabled: !(root.sensitive && lockManager && lockManager.locked)
        opacity: (root.sensitive && lockManager && lockManager.locked) ? 0.25 : 1.0
    }

    UnlockOverlay {
        anchors.fill: parent
        locked: root.sensitive && lockManager && lockManager.locked
        onUnlockRequested: {
            pageStack.push(Qt.resolvedUrl("../pages/UnlockPage.qml"))
        }
    }
}
