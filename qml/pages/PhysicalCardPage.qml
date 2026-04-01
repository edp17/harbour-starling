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

    property string cardTitle: ""
    property string cardLast4: ""
    property bool editingCard: false
    property bool storedCardPresent: false
    property bool storedPinPresent: false
    property bool storedCvvPresent: false

    property var maskedCard: ({})
    property string formError: ""

    function syncPhysicalCardState() {
        formError = ""
        if (starlingClient.locked) {
            storedCardPresent = false
            storedCvvPresent = false
            storedPinPresent = false
            maskedCard = ({})
            storedCvv = ""
            storedPin = ""
            editingCard = false
            clearEditor()
            return
        }

        storedCardPresent = starlingClient.hasStoredPhysicalCard()
        storedCvvPresent = starlingClient.hasStoredPhysicalCardCvv()
        storedPinPresent = starlingClient.hasStoredPhysicalCardPin()

        if (storedCardPresent) {
            maskedCard = starlingClient.loadStoredPhysicalCardMasked()
        } else {
            maskedCard = ({})
        }

        if (!storedCardPresent && !storedCvvPresent && !storedPinPresent) {
            editingCard = false
            clearEditor()
        }
    }

    function clearEditor() {
        if (cardholderNameField)
            cardholderNameField.text = ""
        if (cardNumberField)
            cardNumberField.text = ""
        if (expiryMonthField)
            expiryMonthField.text = ""
        if (expiryYearField)
            expiryYearField.text = ""
        if (cvvField)
            cvvField.text = ""
        if (physicalPinField)
            physicalPinField.text = ""
        if (confirmPhysicalPinField)
            confirmPhysicalPinField.text = ""
    }

    function beginAdd() {
        editingCard = true
        formError = ""
        clearEditor()
        starlingClient.clearPinSettingsError()
    }

    function beginEditFromStoredCard() {
        formError = ""
        starlingClient.clearPinSettingsError()
        requirePinThen(function() {
            var full = starlingClient.loadStoredPhysicalCardFullAfterConfirmation()
            var cvv = starlingClient.loadStoredPhysicalCardCvvAfterConfirmation()
            var pin = starlingClient.loadStoredPhysicalCardPinAfterConfirmation()

            if (full && Object.keys(full).length > 0) {
                cardholderNameField.text = full.cardholderName || ""
                cardNumberField.text = page.formatCardNumber(full.cardNumber || "")
                expiryMonthField.text = full.expiryMonth || ""
                expiryYearField.text = full.expiryYear || ""
                cvvField.text = cvv || ""
                physicalPinField.text = pin || ""
                confirmPhysicalPinField.text = pin || ""
                editingCard = true
            }
        })
    }

    function deleteStoredCard() {
        starlingClient.clearPinSettingsError()
        requirePinThen(function() {
            var okCard = true
            var okCvv = true
            var okPin = true

            if (starlingClient.hasStoredPhysicalCard())
                okCard = starlingClient.deleteStoredPhysicalCardAfterConfirmation()

            if (okCard && starlingClient.hasStoredPhysicalCardCvv())
                okCvv = starlingClient.deleteStoredPhysicalCardCvvAfterConfirmation()

            if (okCard && okCvv && starlingClient.hasStoredPhysicalCardPin())
                okPin = starlingClient.deleteStoredPhysicalCardPinAfterConfirmation()

            if (!okCard || !okCvv || !okPin)
                return

            editingCard = false
            clearEditor()
            syncPhysicalCardState()
        })
    }

    function saveCard() {
        starlingClient.clearPinSettingsError()

        var digits = digitsOnly(cardNumberField.text)
        if (digits.length !== 16) {
            formError = qsTr("Card number must be 16 digits.")
            return
        }

        if (expiryMonthField.text.length !== 2) {
            formError = qsTr("Expiry month must be 2 digits.")
            return
        }

        if (expiryYearField.text.length < 2 || expiryYearField.text.length > 4) {
            formError = qsTr("Expiry year must be 2 or 4 digits.")
            return
        }

        if (cvvField.text.length < 3 || cvvField.text.length > 4) {
            formError = qsTr("Card CVV must be 3 or 4 digits.")
            return
        }

        if (physicalPinField.text.length !== 4 || confirmPhysicalPinField.text.length !== 4) {
            formError = qsTr("Card PIN must be exactly 4 digits.")
            return
        }

        if (physicalPinField.text !== confirmPhysicalPinField.text) {
            formError = qsTr("Card PIN and confirmation do not match.")
            return
        }

        var expectedLast4 = digitsOnly(cardLast4)
        var actualLast4 = digits.slice(-4)

        if (expectedLast4.length === 4 && actualLast4 !== expectedLast4) {
            formError = 
                        qsTr("The entered card number does not match this Starling card ending in %1.")
                        .arg(expectedLast4)
            return
        }

        requirePinThen(function() {
            var okCard = starlingClient.savePhysicalCardAfterConfirmation(
                        cardholderNameField.text,
                        digits,
                        expiryMonthField.text,
                        expiryYearField.text)

            if (!okCard)
                return

            var okCvv = starlingClient.savePhysicalCardCvvAfterConfirmation(cvvField.text)
            if (!okCvv)
                return

            var okPin = starlingClient.savePhysicalCardPinAfterConfirmation(
                        physicalPinField.text,
                        confirmPhysicalPinField.text)
            if (!okPin)
                return

            editingCard = false
            clearEditor()
            syncPhysicalCardState()
        })
    }

    function requirePinThen(action) {
        pinActionRunner.pendingAction = action
        starlingClient.requestPinConfirmation()
    }

    function digitsOnly(value) {
        return (value || "").replace(/\D/g, "")
    }

    function formatCardNumber(value) {
        var digits = digitsOnly(value).slice(0, 16)
        var parts = []
        for (var i = 0; i < digits.length; i += 4)
            parts.push(digits.slice(i, i + 4))
        return parts.join("-")
    }

    function normalizeMonth(value) {
        return digitsOnly(value).slice(0, 2)
    }

    function normalizeYear(value) {
        return digitsOnly(value).slice(0, 4)
    }

    function normalizeCvv(value) {
        return digitsOnly(value).slice(0, 4)
    }

    function normalizePin(value) {
        return digitsOnly(value).slice(0, 4)
    }

    Component.onCompleted: {
        syncPhysicalCardState()
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

        function onLockedChanged() {
            if (starlingClient.locked) {
                page.editingCard = false
                page.storedCardPresent = false
                page.storedCvvPresent = false
                page.storedPinPresent = false
                page.maskedCard = ({})
                page.storedCvv = ""
                page.storedPin = ""
                page.clearEditor()
            } else {
                page.syncPhysicalCardState()
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
                title: qsTr("Physical card")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: cardTitle.length > 0
                text: cardTitle
                color: Theme.highlightColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
            }

            SectionHeader {
                text: qsTr("Stored details")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)
                height: storedDetailsColumn.height + Theme.paddingLarge * 2

                Column {
                    id: storedDetailsColumn
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - Theme.paddingLarge * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Stored details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Store your physical card details securely on-device. Adding, changing or deleting them requires App PIN confirmation.")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: !page.storedCardPresent && !page.storedCvvPresent && !page.storedPinPresent && !page.editingCard
                        text: qsTr("No physical card details are stored yet.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall
                        visible: (page.storedCardPresent || page.storedCvvPresent || page.storedPinPresent) && !page.editingCard

                        Label {
                            width: parent.width
                            text: qsTr("Cardholder name")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            text: page.physicalCardDetailsRevealed
                                  ? ((page.physicalCardFull && page.physicalCardFull.cardholderName) || "")
                                  : ((page.maskedCard && page.maskedCard.cardholderName) || "")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Card number")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            text: page.physicalCardDetailsRevealed
                                  ? ((((page.physicalCardFull && page.physicalCardFull.cardNumber) || "").replace(/(\d{4})(?=\d)/g, "$1-")))
                                  : ((page.maskedCard && page.maskedCard.cardNumber) || "")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.Wrap
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Column {
                                width: (parent.width - Theme.paddingMedium) / 2
                                spacing: Theme.paddingSmall / 2

                                Label {
                                    width: parent.width
                                    text: qsTr("Expiry month")
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Label {
                                    width: parent.width
                                    text: page.physicalCardDetailsRevealed
                                          ? ((page.physicalCardFull && page.physicalCardFull.expiryMonth) || "")
                                          : ((((page.maskedCard && page.maskedCard.expiry) || "").split("/")[0]) || "")
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    wrapMode: Text.Wrap
                                }
                            }

                            Column {
                                width: (parent.width - Theme.paddingMedium) / 2
                                spacing: Theme.paddingSmall / 2

                                Label {
                                    width: parent.width
                                    text: qsTr("Expiry year")
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Label {
                                    width: parent.width
                                    text: page.physicalCardDetailsRevealed
                                          ? ((page.physicalCardFull && page.physicalCardFull.expiryYear) || "")
                                          : ((((page.maskedCard && page.maskedCard.expiry) || "").split("/")[1]) || "")
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Card CVV")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            text: page.physicalCardDetailsRevealed && page.physicalCardCvv.length > 0
                                  ? qsTr("%1").arg(page.physicalCardCvv)
                                  : qsTr("•••")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            text: qsTr("Card PIN")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            text: page.physicalCardPinRevealed && page.physicalCardPin.length > 0
                                  ? qsTr("%1").arg(page.physicalCardPin)
                                  : qsTr("••••")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)
                visible: !page.editingCard
                height: actionsColumn.height + Theme.paddingLarge * 2

                Column {
                    id: actionsColumn
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - Theme.paddingLarge * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Actions")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    Row {
                        id: actionRow
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Button {
                            width: page.storedCardPresent || page.storedCvvPresent || page.storedPinPresent
                                   ? (actionRow.width - actionRow.spacing) / 2
                                   : actionRow.width
                            text: page.storedCardPresent || page.storedCvvPresent || page.storedPinPresent
                                  ? qsTr("Change card")
                                  : qsTr("Add card")
                            onClicked: {
                                if (page.storedCardPresent || page.storedCvvPresent || page.storedPinPresent)
                                    page.beginEditFromStoredCard()
                                else
                                    page.beginAdd()
                            }
                        }

                        Button {
                            width: (actionRow.width - actionRow.spacing) / 2
                            visible: page.storedCardPresent || page.storedCvvPresent || page.storedPinPresent
                            text: qsTr("Delete stored card")
                            onClicked: page.deleteStoredCard()
                        }
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.pinSettingsError.length > 0
                        text: starlingClient.pinSettingsError
                        color: Theme.errorColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)
                visible: page.editingCard
                height: editorColumn.height + Theme.paddingLarge * 2

                Column {
                    id: editorColumn
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - Theme.paddingLarge * 2
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: page.storedCardPresent ? qsTr("Edit card") : qsTr("Add card")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    TextField {
                        id: cardholderNameField
                        width: parent.width
                        label: qsTr("Cardholder name")
                        placeholderText: qsTr("Enter cardholder name")
                        EnterKey.enabled: true
                        onTextChanged: {
                            if (page.formError.length > 0) page.formError = ""
                            if (starlingClient.pinSettingsError.length > 0) starlingClient.clearPinSettingsError()
                        }
                    }

                    TextField {
                        id: cardNumberField
                        width: parent.width
                        label: qsTr("Card number")
                        placeholderText: qsTr("xxxx-xxxx-xxxx-xxxx")
                        inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                        maximumLength: 19
                        onTextChanged: {
                            var formatted = page.formatCardNumber(text)
                            if (text !== formatted) {
                                text = formatted
                                cursorPosition = text.length
                            }
                            if (page.formError.length > 0) page.formError = ""
                            if (starlingClient.pinSettingsError.length > 0) starlingClient.clearPinSettingsError()
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        TextField {
                            id: expiryMonthField
                            width: (parent.width - Theme.paddingMedium) / 2
                            label: qsTr("Expiry month")
                            placeholderText: qsTr("MM")
                            inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                            maximumLength: 2
                            onTextChanged: {
                                var normalized = page.normalizeMonth(text)
                                if (text !== normalized) {
                                    text = normalized
                                    cursorPosition = text.length
                                }
                                if (page.formError.length > 0) page.formError = ""
                                if (starlingClient.pinSettingsError.length > 0) starlingClient.clearPinSettingsError()
                            }
                        }

                        TextField {
                            id: expiryYearField
                            width: (parent.width - Theme.paddingMedium) / 2
                            label: qsTr("Expiry year")
                            placeholderText: qsTr("YY or YYYY")
                            inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                            maximumLength: 4
                            onTextChanged: {
                                var normalized = page.normalizeYear(text)
                                if (text !== normalized) {
                                    text = normalized
                                    cursorPosition = text.length
                                }
                                if (page.formError.length > 0) page.formError = ""
                                if (starlingClient.pinSettingsError.length > 0) starlingClient.clearPinSettingsError()
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Security code (CVV)")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: cvvField
                        width: parent.width
                        label: qsTr("Card CVV")
                        placeholderText: qsTr("3 or 4 digits")
                        inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                        maximumLength: 4
                        onTextChanged: {
                            var normalized = page.normalizeCvv(text)
                            if (text !== normalized) {
                                text = normalized
                                cursorPosition = text.length
                            }
                            if (page.formError.length > 0) page.formError = ""
                            if (starlingClient.pinSettingsError.length > 0) starlingClient.clearPinSettingsError()
                        }
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Card PIN")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: physicalPinField
                        width: parent.width
                        label: qsTr("Card PIN")
                        placeholderText: qsTr("4 digits")
                        inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                        maximumLength: 4
                        onTextChanged: {
                            var normalized = page.normalizePin(text)
                            if (text !== normalized) {
                                text = normalized
                                cursorPosition = text.length
                            }
                            if (page.formError.length > 0) page.formError = ""
                            if (starlingClient.pinSettingsError.length > 0) starlingClient.clearPinSettingsError()
                        }
                    }

                    TextField {
                        id: confirmPhysicalPinField
                        width: parent.width
                        label: qsTr("Confirm card PIN")
                        placeholderText: qsTr("Re-enter 4 digits")
                        inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                        maximumLength: 4
                        onTextChanged: {
                            var normalized = page.normalizePin(text)
                            if (text !== normalized) {
                                text = normalized
                                cursorPosition = text.length
                            }
                            if (page.formError.length > 0) page.formError = ""
                            if (starlingClient.pinSettingsError.length > 0) starlingClient.clearPinSettingsError()
                        }
                    }

                    Label {
                        width: parent.width
                        visible: page.formError.length > 0 || starlingClient.pinSettingsError.length > 0
                        text: page.formError.length > 0 ? page.formError : starlingClient.pinSettingsError
                        color: Theme.errorColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        id: editorButtonRow
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Button {
                            width: (editorButtonRow.width - editorButtonRow.spacing) / 2
                            text: qsTr("Save")
                            onClicked: page.saveCard()
                        }

                        Button {
                            width: (editorButtonRow.width - editorButtonRow.spacing) / 2
                            text: qsTr("Cancel")
                            onClicked: {
                                page.editingCard = false
                                page.clearEditor()
                                starlingClient.clearPinSettingsError()
                                page.syncPhysicalCardState()
                            }
                        }
                    }
                }
            }


            Item {
                width: 1
                height: Theme.paddingLarge
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
}
