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

    property string text: ""
    property bool error: false
    property bool compact: false

    width: parent ? parent.width : Screen.width
    height: visible ? messageCard.height + Theme.paddingSmall : 0
    visible: text.trim().length > 0

    Rectangle {
        id: messageCard
        x: Theme.horizontalPageMargin
        y: 0
        width: root.width - Theme.horizontalPageMargin * 2
        height: messageLabel.height + (root.compact ? Theme.paddingMedium * 2
                                                    : Theme.paddingLarge * 2)
        radius: Theme.paddingMedium
        color: root.error
               ? Theme.rgba(Theme.errorColor, 0.10)
               : Theme.rgba(Theme.highlightBackgroundColor, 0.12)
        border.width: 1
        border.color: root.error
                      ? Theme.rgba(Theme.errorColor, 0.28)
                      : Theme.rgba(Theme.highlightColor, 0.18)

        Label {
            id: messageLabel
            x: root.compact ? Theme.paddingMedium : Theme.paddingLarge
            y: root.compact ? Theme.paddingMedium : Theme.paddingLarge
            width: parent.width - x * 2
            text: root.text
            color: root.error ? Theme.errorColor : Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }
    }
}
