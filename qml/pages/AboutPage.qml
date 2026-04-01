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
    id: aboutPage

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("About")
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Starling Bank")
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.highlightColor
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Personal account client")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            Image {
                source: "/usr/share/icons/hicolor/172x172/apps/harbour-starling.png"
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.22
                height: width
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Version ") + (Qt.application.version ? Qt.application.version : "1.0")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.secondaryColor
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                height: overviewColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: overviewColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - Theme.paddingMedium * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Overview")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Harbour Starling is a Sailfish OS client for managing your Starling Bank account using Personal Access Tokens.")
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                height: featuresColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: featuresColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - Theme.paddingMedium * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Features")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("• View account balance and details\n• Browse transactions and activity\n• Manage payees and their accounts\n• Make payments with full review and confirmation\n• Control card settings and view card details\n• Store physical card details securely on-device\n• App PIN protection with automatic locking")
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                height: securityColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: securityColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - Theme.paddingMedium * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Security")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Sensitive data such as tokens, API keys and card details are stored securely on-device. Critical actions like payments and access to sensitive information require App PIN confirmation.")
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                height: notesColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: notesColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - Theme.paddingMedium * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Notes")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("This application is not affiliated with or endorsed by Starling Bank. Use it at your own discretion and keep your Personal Access Tokens secure.")
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                height: developerColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: developerColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - Theme.paddingMedium * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Developer")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Developed by: edp17")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("This project is licensed under GNU GPL 3.0 or later.\nCopyright (c) 2026 edp17.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Button {
                text: qsTr("Source code")
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - Theme.paddingLarge * 2, Theme.buttonWidthLarge)
                onClicked: Qt.openUrlExternally("https://github.com/edp17/harbour-starling")
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }
        }
    }

    ActivityCatcher {
        z: 999
    }
}
