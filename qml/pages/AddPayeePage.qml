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

    property bool formUnlocked: !starlingClient.locked
    property bool hasMainToken: starlingClient.token.length > 0
    property bool hasPayeeWriteToken: starlingClient.payeeWriteToken.length > 0
    property bool readyForContent: formUnlocked && hasMainToken && hasPayeeWriteToken

    function currentPayeeType() {
        return payeeTypeCombo.currentIndex === 1 ? "BUSINESS" : "INDIVIDUAL"
    }

    function isIndividual() {
        return currentPayeeType() === "INDIVIDUAL"
    }

    function isBusiness() {
        return currentPayeeType() === "BUSINESS"
    }

    function normalizedSortCode(value) {
        return value.replace(/-/g, "").replace(/\s/g, "")
    }

    function digitsOnly(value) {
        return value.replace(/[^0-9]/g, "")
    }

    function formattedSortCode(value) {
        var d = digitsOnly(value)
        if (d.length <= 2)
            return d
        if (d.length <= 4)
            return d.slice(0, 2) + "-" + d.slice(2)
        return d.slice(0, 2) + "-" + d.slice(2, 4) + "-" + d.slice(4, 6)
    }

    function submitEnabled() {
        if (payeeNameField.text.trim().length === 0)
            return false

        if (accountLabelField.text.trim().length === 0)
            return false

        if (accountNumberField.text.trim().length === 0)
            return false

        if (normalizedSortCode(sortCodeField.text).length === 0)
            return false

        if (isIndividual()) {
            if (firstNameField.text.trim().length === 0)
                return false
            if (lastNameField.text.trim().length === 0)
                return false
        }

        if (isBusiness()) {
            if (businessNameField.text.trim().length === 0)
                return false
        }

        return true
    }

    Connections {
        target: starlingClient

        onStatusChanged: {
            if (starlingClient.status.indexOf("Payee created.") !== -1) {
                starlingClient.refreshPayees()
                pageStack.pop()
            }
        }
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
                title: qsTr("Add payee")
            }

            Item {
                width: parent.width
                height: formUnlocked ? 0 : lockColumn.height + Theme.paddingLarge
                visible: !formUnlocked

                Column {
                    id: lockColumn
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    spacing: Theme.paddingLarge

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: qsTr("This form is locked. Unlock before creating or changing payees.")
                    }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Unlock payee actions")
                        onClicked: starlingClient.unlock()
                    }
                }
            }

            Item {
                width: parent.width
                height: visible ? noMainTokenCard.height + Theme.itemSizeMedium : 0
                visible: formUnlocked && !hasMainToken

                Rectangle {
                    id: noMainTokenCard
                    x: Theme.horizontalPageMargin
                    y: Theme.itemSizeSmall
                    width: parent.width - Theme.horizontalPageMargin * 2
                    height: noMainTokenColumn.height + Theme.paddingLarge * 2
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.22)

                    Column {
                        id: noMainTokenColumn
                        x: Theme.paddingLarge
                        y: Theme.paddingLarge
                        width: parent.width - Theme.paddingLarge * 2
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: qsTr("No account access configured")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Open Settings to add your access token.")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: visible ? noWriteTokenCard.height + Theme.itemSizeMedium : 0
                visible: formUnlocked && hasMainToken && !hasPayeeWriteToken

                Rectangle {
                    id: noWriteTokenCard
                    x: Theme.horizontalPageMargin
                    y: Theme.itemSizeSmall
                    width: parent.width - Theme.horizontalPageMargin * 2
                    height: noWriteTokenColumn.height + Theme.paddingLarge * 2
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.22)

                    Column {
                        id: noWriteTokenColumn
                        x: Theme.paddingLarge
                        y: Theme.paddingLarge
                        width: parent.width - Theme.paddingLarge * 2
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: qsTr("Payee creation is not available")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Open Settings to add your payee-write token.")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: readyForContent

                ComboBox {
                    id: payeeTypeCombo
                    label: qsTr("Payee type")

                    menu: ContextMenu {
                        MenuItem { text: qsTr("Individual") }
                        MenuItem { text: qsTr("Business") }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Payee name")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: payeeNameField
                        width: parent.width
                        placeholderText: qsTr("Required")
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("This is the main display name shown in your saved payees list.")
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: false

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Phone number")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: phoneNumberField
                        width: parent.width
                        placeholderText: qsTr("Optional")
                    }
                }

                SectionHeader {
                    text: qsTr("Details")
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: page.isIndividual()

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("First name")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: firstNameField
                        width: parent.width
                        placeholderText: qsTr("Required for individuals")
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: page.isIndividual()

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Middle name")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: middleNameField
                        width: parent.width
                        placeholderText: qsTr("Optional")
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: page.isIndividual()

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Last name")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: lastNameField
                        width: parent.width
                        placeholderText: qsTr("Required for individuals")
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: page.isBusiness()

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Business name")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: businessNameField
                        width: parent.width
                        placeholderText: qsTr("Required for businesses")
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: false//page.isIndividual()

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Date of birth")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: dateOfBirthField
                        width: parent.width
                        placeholderText: "YYYY-MM-DD"
                    }
                }

                SectionHeader {
                    text: qsTr("Bank account")
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Account label")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: accountLabelField
                        width: parent.width
                        placeholderText: qsTr("Required")
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("A label for this saved account, for example “Main account” or “Business account”.")
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Account number")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: accountNumberField
                        width: parent.width
                        placeholderText: qsTr("Required")
                        inputMethodHints: Qt.ImhDigitsOnly
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("Usually 8 digits for UK bank accounts.")
                }

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: qsTr("Sort code")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: sortCodeField
                        width: parent.width
                        placeholderText: qsTr("Required")
                        inputMethodHints: Qt.ImhDigitsOnly

                        onTextChanged: {
                            var f = page.formattedSortCode(text)
                            if (text !== f)
                                text = f
                        }
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("UK bank sort code, for example 12-34-56.")
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Create payee")
                    enabled: page.submitEnabled() && !starlingClient.busy
                    onClicked: {
                        starlingClient.createPayee(
                                    payeeNameField.text.trim(),
                                    phoneNumberField.text.trim(),
                                    page.currentPayeeType(),
                                    firstNameField.text.trim(),
                                    middleNameField.text.trim(),
                                    lastNameField.text.trim(),
                                    businessNameField.text.trim(),
                                    dateOfBirthField.text.trim(),
                                    accountLabelField.text.trim(),
                                    true,
                                    "GB",
                                    accountNumberField.text.trim(),
                                    page.normalizedSortCode(sortCodeField.text),
                                    "SORT_CODE",
                                    ""
                                    )
                    }
                }
            }

            BusyIndicator {
                x: Theme.horizontalPageMargin
                size: BusyIndicatorSize.Medium
                running: starlingClient.busy && readyForContent
                visible: running
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                text: starlingClient.status
                visible: text.length > 0
            }

            SectionHeader {
                text: qsTr("Notes")
                visible: readyForContent
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                visible: readyForContent
                text: qsTr("This simplified form currently assumes a UK bank account and uses country GB with bank identifier type SORT_CODE.")
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
