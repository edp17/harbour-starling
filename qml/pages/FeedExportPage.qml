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

    function todayIsoDate() {
        return new Date().toISOString().substring(0, 10)
    }

    function daysAgoIsoDate(days) {
        var d = new Date()
        d.setDate(d.getDate() - days)
        return d.toISOString().substring(0, 10)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Feed export")
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
                        text: qsTr("Export transaction feed")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Choose a date range and save a CSV feed export to Documents/Starling Feed Exports.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: startField
                        width: parent.width
                        label: qsTr("Start date")
                        placeholderText: qsTr("YYYY-MM-DD")
                        text: page.daysAgoIsoDate(30)
                        inputMethodHints: Qt.ImhDigitsOnly
                    }

                    TextField {
                        id: endField
                        width: parent.width
                        label: qsTr("End date")
                        placeholderText: qsTr("YYYY-MM-DD")
                        text: page.todayIsoDate()
                        inputMethodHints: Qt.ImhDigitsOnly
                    }

                    Button {
                        width: parent.width
                        enabled: page.readyForContent && !starlingClient.busy
                        text: starlingClient.busy ? qsTr("Downloading...") : qsTr("Download CSV")
                        onClicked: starlingClient.downloadFeedExportCsvRange(startField.text.trim(),
                                                                             endField.text.trim())
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: starlingClient.lastFeedExportCsvPath.length > 0
                text: qsTr("Last saved:\n%1").arg(starlingClient.lastFeedExportCsvPath)
                color: Theme.secondaryColor
                wrapMode: Text.WrapAnywhere
                font.pixelSize: Theme.fontSizeSmall
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

    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: qsTr("Authenticate to export feed.")
        busy: starlingClient.busy
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
