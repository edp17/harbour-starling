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

Rectangle {
    property var fields: []
    property bool secondary: false
    property string title: ""

    x: Theme.horizontalPageMargin
    width: parent.width - 2 * x
    height: sectionColumn.height + 2 * Theme.paddingMedium
    radius: Theme.paddingMedium
    color: Theme.rgba(Theme.highlightBackgroundColor, secondary ? 0.12 : 0.25)
    border.width: 1
    border.color: Theme.rgba(Theme.primaryColor, secondary ? 0.12 : 0.15)

    Column {
        id: sectionColumn
        x: Theme.paddingMedium
        y: Theme.paddingMedium
        width: parent.width - 2 * Theme.paddingMedium
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            visible: title.length > 0
            text: title
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeSmall
        }

        Repeater {
            model: fields

            Label {
                width: parent.width
                text: modelData
                color: secondary ? Theme.secondaryColor : Theme.primaryColor
                font.pixelSize: secondary ? Theme.fontSizeExtraSmall : Theme.fontSizeSmall
                wrapMode: Text.WrapAnywhere
            }
        }
    }
}
