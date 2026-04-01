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

    function hasText(value) {
        return value !== undefined && value !== null && String(value).length > 0
    }

    property bool isOnline: starlingClient.online

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge
        visible: !starlingClient.locked

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Account details")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                height: offlineColumn.height + Theme.paddingLarge * 2
                visible: !page.isOnline
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.22)

                Column {
                    id: offlineColumn
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - Theme.paddingLarge * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("No internet connection")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Reconnect to load data.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.isOnline && hasText(starlingClient.accountName)
                text: starlingClient.accountName
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeLarge
                wrapMode: Text.Wrap
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.isOnline
                text: qsTr("Core details for your selected Starling account.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.isOnline
                height: detailsColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: detailsColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.accountName)

                        Label {
                            width: parent.width
                            text: qsTr("Account name")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.accountName
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.accountType)

                        Label {
                            width: parent.width
                            text: qsTr("Account type")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.accountType
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: hasText(starlingClient.accountNumber) || hasText(starlingClient.sortCode)

                        Column {
                            width: parent.width / 2 - Theme.paddingMedium / 2
                            spacing: Theme.paddingSmall / 2
                            visible: hasText(starlingClient.accountNumber)

                            Label {
                                width: parent.width
                                text: qsTr("Account number")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            Label {
                                width: parent.width
                                text: starlingClient.accountNumber
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                            }
                        }

                        Column {
                            width: parent.width / 2 - Theme.paddingMedium / 2
                            spacing: Theme.paddingSmall / 2
                            visible: hasText(starlingClient.sortCode)

                            Label {
                                width: parent.width
                                text: qsTr("Sort code")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }

                            Label {
                                width: parent.width
                                text: starlingClient.sortCode
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.currency)

                        Label {
                            width: parent.width
                            text: qsTr("Currency")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.currency
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }
        }
    }

    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: qsTr("Authenticate to access your Starling data.")
        busy: starlingClient.busy
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
