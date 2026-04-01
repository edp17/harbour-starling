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
                title: qsTr("Security")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: importantColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: importantColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Important")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Anyone with access to your unlocked device or active app session may be able to access your account information.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("If you believe a token has been exposed, revoke it in your Starling developer settings and replace it in this app.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: authColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: authColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Personal Access Token")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("The Personal Access Token is used for access your Starling account data from this app.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("It is stored securely on your device so you do not need to enter it every time you open the app.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: payeeTokenColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: payeeTokenColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Payee write token")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("The payee write token is used only for actions that create or modify payees.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("It is stored separately from the main Personal Access Token because it grants additional permissions.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: signingColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: signingColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Payment signing")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Payments require both an API Key UID and a PEM private key. These are used to sign payment requests before submission.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Without valid signing credentials, payment creation remains unavailable.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: lockColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: lockColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("App lock")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("When the app locks, sensitive account data is hidden until you unlock the app again.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("You can configure whether the app locks immediately when sent to the background, or only after the selected inactivity timeout.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: pinColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: pinColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("App PIN")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("If enabled, the app PIN is required before the app can be unlocked and sensitive actions can be confirmed.")
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("The PIN helps protect your session on the device, but it does not replace good device security.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        wrapMode: Text.Wrap
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("You can manage tokens, API keys and App PIN from Settings.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall * 0.9
                wrapMode: Text.Wrap
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
