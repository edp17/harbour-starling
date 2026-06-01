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

    property bool isOnline: starlingClient.online
    property bool editingEmail: false
    property string pageError: ""
    property string emailVerificationMessage: ""

    function canEditEmail() {
        return !starlingClient.locked && starlingClient.token.length > 0
    }

    function requirePinThen(action) {
        pinActionRunner.pendingAction = action
        starlingClient.requestPinConfirmation()
    }

    function saveEmail() {
        page.pageError = ""

        var email = emailField.text.trim()

        if (email.length === 0 || email.indexOf("@") < 0 || email.indexOf(".") < 0) {
            page.pageError = qsTr("Enter a valid email address.")
            return
        }

        requirePinThen(function() {
            starlingClient.updateAccountHolderEmail(email)
        })
    }

    function hasText(value) {
        return value !== undefined && value !== null && String(value).length > 0
    }

    Component.onCompleted: {
        if (!starlingClient.locked && starlingClient.token.length > 0)
            starlingClient.refreshAccountHolderBasic()
    }

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
                title: qsTr("Account holder")
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
                visible: page.isOnline && hasText(starlingClient.accountHolderName)
                text: starlingClient.accountHolderName
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeLarge
                wrapMode: Text.Wrap
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.isOnline
                text: qsTr("Personal details stored for your Starling account.")
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
                        visible: hasText(starlingClient.accountHolderName)

                        Label {
                            width: parent.width
                            text: qsTr("Account holder")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.accountHolderName
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.accountHolderBasic.accountHolderState || "")

                        Label {
                            width: parent.width
                            text: qsTr("Account state")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.accountHolderBasic.accountHolderState || ""
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.accountHolderBasic.accountHolderType || "")

                        Label {
                            width: parent.width
                            text: qsTr("Account type")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.accountHolderBasic.accountHolderType || ""
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.phone)

                        Label {
                            width: parent.width
                            text: qsTr("Mobile number")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.phone
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.email)

                        Label {
                            width: parent.width
                            text: qsTr("Email address")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            visible: !page.editingEmail
                            text: starlingClient.email || ""
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }

                        TextField {
                            id: emailField
                            width: parent.width
                            visible: page.editingEmail
                            label: qsTr("Email address")
                            text: starlingClient.email || ""
                            inputMethodHints: Qt.ImhEmailCharactersOnly
                            enabled: page.canEditEmail() && !starlingClient.busy
                            onTextChanged: page.pageError = ""
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingSmall

                            TextSwitch {
                                id: editEmailSwitch
                                width: parent.width - Theme.itemSizeLarge - Theme.paddingSmall
                                text: qsTr("Edit email")
                                checked: page.editingEmail
                                enabled: page.canEditEmail() && !starlingClient.busy

                                onCheckedChanged: {
                                    page.editingEmail = checked
                                    if (checked)
                                        emailField.text = starlingClient.email || ""
                                }
                            }

                            Button {
                                width: Theme.itemSizeLarge
                                visible: page.editingEmail
                                enabled: page.canEditEmail() && !starlingClient.busy
                                text: qsTr("Save")
                                onClicked: page.saveEmail()
                            }
                        }

                        Rectangle {
                            x: Theme.horizontalPageMargin
                            width: parent.width - 2 * x
                            height: emailVerificationColumn.height + 2 * Theme.paddingMedium
                            visible: page.emailVerificationMessage.length > 0

                            radius: Theme.paddingMedium
                            color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                            border.width: 1
                            border.color: Theme.rgba(Theme.highlightColor, 0.35)

                            Column {
                                id: emailVerificationColumn
                                x: Theme.paddingMedium
                                y: Theme.paddingMedium
                                width: parent.width - 2 * Theme.paddingMedium
                                spacing: Theme.paddingMedium

                                Label {
                                    width: parent.width
                                    text: qsTr("Verify your email address")
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.bold: true
                                }

                                Label {
                                    width: parent.width
                                    text: page.emailVerificationMessage
                                    color: Theme.primaryColor
                                    wrapMode: Text.Wrap
                                }

                                Button {
                                    width: parent.width
                                    text: qsTr("OK")
                                    onClicked: page.emailVerificationMessage = ""
                                }
                            }
                        }

                        Label {
                            width: parent.width
                            visible: page.pageError.length > 0
                            text: page.pageError
                            color: Theme.errorColor
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.postalAddress)

                        Label {
                            width: parent.width
                            text: qsTr("Postal address")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.postalAddress
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2
                        visible: hasText(starlingClient.countryCode)

                        Label {
                            width: parent.width
                            text: qsTr("Country")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            text: starlingClient.countryCode
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

    QtObject {
        id: pinActionRunner
        property var pendingAction: null
    }

    Connections {
        target: starlingClient

        onPinConfirmed: {
            if (pinActionRunner.pendingAction) {
                var action = pinActionRunner.pendingAction
                pinActionRunner.pendingAction = null
                action()
            }
        }

        onAccountHolderEmailUpdated: {
            page.editingEmail = false
            editEmailSwitch.checked = false
            page.pageError = ""

            page.emailVerificationMessage =
                    qsTr("We have sent an email to\n%1\n\nPlease open the email and click the provided link to confirm your email address.")
                    .arg(email)
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
