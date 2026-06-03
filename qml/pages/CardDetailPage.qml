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

    property var cardData: ({})
    property bool editMode: false

    property bool enabledValue: false
    property bool posEnabledValue: false
    property bool atmEnabledValue: false
    property bool onlineEnabledValue: false
    property bool mobileWalletEnabledValue: false
    property bool gamblingEnabledValue: false
    property bool magStripeEnabledValue: false
    property bool showMagStripeConfirm: false
    property bool showConsentOverlay: false
    property bool readyForContent: !starlingClient.locked

    property var physicalCardMasked: ({})
    property var physicalCardFull: ({})
    property string physicalCardCvv: ""
    property string physicalCardPin: ""
    property bool physicalCardDetailsRevealed: false
    property bool physicalCardPinRevealed: false
    property string physicalCardError: ""
    property bool hasLocalPhysicalCardData: false
    property bool isOnline: starlingClient.online

    function refreshPhysicalCardSummary() {
        hasLocalPhysicalCardData =
                starlingClient.hasStoredPhysicalCard()
                || starlingClient.hasStoredPhysicalCardCvv()
                || starlingClient.hasStoredPhysicalCardPin()

        physicalCardContainer.hasCard = hasLocalPhysicalCardData
        physicalCardMasked = starlingClient.hasStoredPhysicalCard()
                ? starlingClient.loadStoredPhysicalCardMasked()
                : ({})
        if (!physicalCardContainer.hasCard) {
            physicalCardFull = ({})
            physicalCardCvv = ""
            physicalCardPin = ""
            physicalCardDetailsRevealed = false
            physicalCardPinRevealed = false
            physicalCardError = ""
        }
    }

    function resetPhysicalCardRevealState() {
        physicalCardFull = ({})
        physicalCardCvv = ""
        physicalCardPin = ""
        physicalCardDetailsRevealed = false
        physicalCardPinRevealed = false
        physicalCardError = ""
    }

    function requirePinThen(action) {
        pinActionRunner.pendingAction = action
        starlingClient.requestPinConfirmation()
    }

    QtObject {
        id: pinActionRunner
        property var pendingAction: null
    }

    function yesNo(v) {
        return v ? qsTr("Yes") : qsTr("No")
    }

    function activeInactive(v) {
        return v ? qsTr("Active") : qsTr("Disabled")
    }

    function controlColor(v) {
        return v ? "#2fb344" : "#d4a017"
    }

    function currencySummary() {
        var flags = cardData.currencyFlags || []
        if (flags.length === 0)
            return qsTr("Not available")

        var enabledCurrencies = []
        for (var i = 0; i < flags.length; ++i) {
            if (flags[i].enabled)
                enabledCurrencies.push(flags[i].currency)
        }

        if (enabledCurrencies.length === 0)
            return qsTr("None enabled")

        return enabledCurrencies.join(", ")
    }

    function currentEnabledState() {
        return page.editMode ? page.enabledValue : cardData.enabled
    }

    function beginEdit() {
        enabledValue = !!cardData.enabled
        posEnabledValue = !!cardData.posEnabled
        atmEnabledValue = !!cardData.atmEnabled
        onlineEnabledValue = !!cardData.onlineEnabled
        mobileWalletEnabledValue = !!cardData.mobileWalletEnabled
        gamblingEnabledValue = !!cardData.gamblingEnabled
        magStripeEnabledValue = !!cardData.magStripeEnabled
        editMode = true
    }

    function cancelEdit() {
        editMode = false
        enabledValue = !!cardData.enabled
        posEnabledValue = !!cardData.posEnabled
        atmEnabledValue = !!cardData.atmEnabled
        onlineEnabledValue = !!cardData.onlineEnabled
        mobileWalletEnabledValue = !!cardData.mobileWalletEnabled
        gamblingEnabledValue = !!cardData.gamblingEnabled
        magStripeEnabledValue = !!cardData.magStripeEnabled
    }

    function posHelpText(v) {
        return v
                ? qsTr("Your card is unlocked and ready to use for contactless and chip and pin card payments.")
                : qsTr("Your card is locked for contactless and chip and pin card payments - so your money is safe if you lose your card.")
    }

    function atmHelpText(v) {
        return v
                ? qsTr("Your card is unlocked and ready to use for ATM withdrawals.")
                : qsTr("Your card is locked for ATM withdrawals - preventing withdrawals if your card fails into the wrong hands.")
    }

    function onlineHelpText(v) {
        return v
                ? qsTr("Your card is unlocked and ready to use online.")
                : qsTr("Your card is locked for online transactions. This may not prevent online subscription payments you have already authorised.")
    }

    function mobileWalletHelpText(v) {
        return v
                ? qsTr("Your card is unlocked and ready to use for mobile wallet transactions.")
                : qsTr("Your card is locked for mobile wallet transactions. Keep it locked if you won't be using your mobile wallet.")
    }

    function magStripeHelpText(v) {
        return v
                ? qsTr("Magstripe payments are currently unlocked on your card. They will be automatically locked after 48 hours of not being used to help protect you from fraud.")
                : qsTr("Magstripe payments mean you can pay by swiping your card. These are locked to protect you from fraud.")
    }

    function togglePhysicalCardDetails() {
        if (physicalCardDetailsRevealed) {
            physicalCardFull = ({})
            physicalCardCvv = ""
            physicalCardDetailsRevealed = false
            physicalCardError = ""
            return
        }

        revealPhysicalCardDetails()
    }

    function togglePhysicalCardPin() {
        if (physicalCardPinRevealed) {
            physicalCardPin = ""
            physicalCardPinRevealed = false
            physicalCardError = ""
            return
        }

        revealPhysicalCardPin()
    }

    function revealPhysicalCardDetails() {
        physicalCardError = ""
        starlingClient.clearPinSettingsError()

        requirePinThen(function() {
            var full = starlingClient.loadStoredPhysicalCardFullAfterConfirmation()
            if (!full || Object.keys(full).length === 0) {
                physicalCardError = starlingClient.pinSettingsError
                return
            }

            var cvv = ""
            if (starlingClient.hasStoredPhysicalCardCvv()) {
                cvv = starlingClient.loadStoredPhysicalCardCvvAfterConfirmation()
                if (cvv.length === 0 && starlingClient.pinSettingsError.length > 0) {
                    physicalCardError = starlingClient.pinSettingsError
                    return
                }
            }

            physicalCardFull = full
            physicalCardCvv = cvv
            physicalCardDetailsRevealed = true
        })
    }

    function revealPhysicalCardPin() {
        physicalCardError = ""
        starlingClient.clearPinSettingsError()

        requirePinThen(function() {
            var pin = starlingClient.loadStoredPhysicalCardPinAfterConfirmation()
            if (pin.length === 0) {
                physicalCardError = starlingClient.pinSettingsError
                return
            }

            physicalCardPin = pin
            physicalCardPinRevealed = true
        })
    }

    function fallbackMaskedCardNumber() {
        var title = cardData && cardData.title ? cardData.title : ""
        var digits = title.replace(/\D/g, "")
        var last4 = digits.length >= 4 ? digits.slice(-4) : "----"
        return "****-****-****-" + last4
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            refreshPhysicalCardSummary()
        }
    }

    Component.onCompleted: {
        cancelEdit()
        refreshPhysicalCardSummary()
        resetPhysicalCardRevealState()
    }

    Connections {
        target: starlingClient

        onConsentPendingChanged: {
            if (starlingClient.consentPending) {
                page.showConsentOverlay = true
                page.editMode = false
            }
        }
        function onLockedChanged() {
            if (starlingClient.locked) {
                page.editMode = false
                page.showMagStripeConfirm = false
                page.showConsentOverlay = false
            }
        }

        onPinConfirmed: {
            if (pinActionRunner.pendingAction) {
                var action = pinActionRunner.pendingAction
                pinActionRunner.pendingAction = null
                action()
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge
        visible: !starlingClient.locked

        PullDownMenu {
            busy: starlingClient.busy

            MenuItem {
                visible: page.isOnline
                text: page.editMode ? qsTr("Cancel edit") : qsTr("Edit card")

                onClicked: {
                    if (page.editMode)
                        cancelEdit()
                    else
                        beginEdit()
                }
            }
            MenuItem {
                text: qsTr("Maintain Physical card")
                onClicked: {
                    page.resetPhysicalCardRevealState()

                    var title = cardData.title || ""
                    var digits = title.replace(/\D/g, "")
                    var last4 = digits.length >= 4 ? digits.slice(-4) : ""
                    pageStack.push(Qt.resolvedUrl("PhysicalCardPage.qml"), {
                        "cardTitle": title,
                        "cardLast4": last4
                    })
                }
            }
        }

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Card details")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !page.isOnline
                text: qsTr("Offline. Stored physical card details remain available, but live card controls are unavailable.")
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            SectionHeader {
                text: qsTr("Card")
            }

            Rectangle {
                id: physicalCardContainer

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: width * 0.62
                radius: Theme.paddingLarge

                color: Theme.rgba(page.controlColor(page.enabledValue), 0.3)
                border.color: page.controlColor(page.enabledValue)
                border.width: 3

                property var maskedCard: starlingClient.loadStoredPhysicalCardMasked()
                property bool hasCard: false

                visible: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var title = cardData && cardData.title ? cardData.title : ""
                        var digits = title.replace(/\D/g, "")
                        var last4 = digits.length >= 4 ? digits.slice(-4) : ""

                        pageStack.push(Qt.resolvedUrl("PhysicalCardPage.qml"), {
                            cardTitle: title,
                            cardLast4: last4
                        })
                    }
                }

                // Stored card details
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: physicalCardBottomRow.top
                    anchors.margins: Theme.paddingLarge
                    spacing: Theme.paddingSmall
                    visible: physicalCardContainer.hasCard

                    Item {
                        width: parent.width
                        height: Math.max(bankIcon.height, bankLabel.implicitHeight)

                        Item {
                            width: frozenLabel.implicitWidth
                            height: frozenLabel.implicitHeight
                            anchors.left: parent.left
                            visible: physicalCardContainer.hasCard

                            Label {
                                id: frozenLabel
                                text: !page.enabledValue ? qsTr("FROZEN") : qsTr("")
                                color: page.controlColor(page.enabledValue)
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        Item {
                            id: bankBrand
                            width: bankIcon.width + Theme.paddingSmall + bankLabel.implicitWidth
                            height: Math.max(bankIcon.height, bankLabel.implicitHeight)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: bankIcon
                                source: "file:///usr/share/icons/hicolor/172x172/apps/harbour-starling.png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                fillMode: Image.PreserveAspectFit
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: bankLabel
                                text: qsTr("Starling Bank")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                anchors.left: bankIcon.right
                                anchors.leftMargin: Theme.paddingSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        text: page.physicalCardDetailsRevealed
                              ? ((page.physicalCardFull.cardNumber || "").replace(/(\d{4})(?=\d)/g, "$1-"))
                              : (page.physicalCardMasked.cardNumber || "")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Item {
                        width: 1
                        height: Theme.paddingSmall / 2
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingLarge

                        Column {
                            width: parent.width * 0.5
                            spacing: Theme.paddingSmall / 2

                            Label {
                                text: qsTr("Cardholder")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }

                            Label {
                                width: parent.width
                                text: page.physicalCardDetailsRevealed
                                      ? (page.physicalCardFull.cardholderName || "")
                                      : (page.physicalCardMasked.cardholderName || "")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                            }
                        }

                        Column {
                            width: parent.width * 0.2
                            spacing: Theme.paddingSmall / 2

                            Label {
                                text: qsTr("Expiry")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }

                            Label {
                                text: page.physicalCardDetailsRevealed
                                      ? ((page.physicalCardFull.expiryMonth || "") + "/" + (page.physicalCardFull.expiryYear || ""))
                                      : (page.physicalCardMasked.expiry || "")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primaryColor
                            }
                        }

                        Column {
                            width: parent.width - (parent.width * 0.5) - (parent.width * 0.2) - parent.spacing * 2
                            spacing: Theme.paddingSmall / 2

                            Label {
                                text: qsTr("PIN")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }

                            Rectangle {
                                width: parent.width
                                height: pinValue.implicitHeight + Theme.paddingSmall
                                radius: Theme.paddingSmall
                                color: Theme.rgba(Theme.highlightColor, 0.10)
                                border.width: 1
                                border.color: Theme.rgba(Theme.highlightColor, 0.22)

                                Label {
                                    id: pinValue
                                    anchors.centerIn: parent
                                    text: page.physicalCardPinRevealed && page.physicalCardPin.length > 0
                                          ? qsTr("%1").arg(page.physicalCardPin)
                                          : qsTr("••••")
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.bold: true
                                    color: Theme.highlightColor
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Math.max(cvvLabel.implicitHeight, cvvBox.height)

                        Label {
                            id: cvvLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("CVV")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }

                        Rectangle {
                            id: cvvBox
                            x: cvvLabel.implicitWidth + Theme.paddingMedium
                            y: (parent.height - height) / 2
                            width: Math.max(Theme.itemSizeSmall, cvvValue.implicitWidth + Theme.paddingLarge)
                            height: cvvValue.implicitHeight + Theme.paddingSmall
                            radius: Theme.paddingSmall
                            color: Theme.rgba(Theme.highlightColor, 0.10)
                            border.width: 1
                            border.color: Theme.rgba(Theme.highlightColor, 0.22)

                            Label {
                                id: cvvValue
                                anchors.centerIn: parent
                                text: page.physicalCardDetailsRevealed && page.physicalCardCvv.length > 0
                                      ? qsTr("%1").arg(page.physicalCardCvv)
                                      : qsTr("•••")
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                color: Theme.highlightColor
                            }
                        }
                    }
                }

                // If no stored card details, show a message
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: physicalCardBottomRow.top
                    anchors.margins: Theme.paddingLarge
                    spacing: Theme.paddingMedium
                    visible: !physicalCardContainer.hasCard

                    Item {
                        width: parent.width
                        height: Math.max(bankIconEmpty.height, bankLabelEmpty.implicitHeight)

                        Item {
                            width: bankIconEmpty.width + Theme.paddingSmall + bankLabelEmpty.implicitWidth
                            height: Math.max(bankIconEmpty.height, bankLabelEmpty.implicitHeight)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: bankIconEmpty
                                source: "file:///usr/share/icons/hicolor/172x172/apps/harbour-starling.png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                fillMode: Image.PreserveAspectFit
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: bankLabelEmpty
                                text: qsTr("Starling Bank")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                anchors.left: bankIconEmpty.right
                                anchors.leftMargin: Theme.paddingSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        text: page.fallbackMaskedCardNumber()
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Item {
                        width: 1
                        height: Theme.paddingSmall
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Column {
                            width: parent.width
                            spacing: Theme.paddingSmall / 2

                            Label {
                                width: parent.width
                                text: qsTr("Add physical card details")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                            }
                            Label {
                                width: parent.width
                                text: qsTr("Tap to store Cardholder name, Card number, Expiry, CVV and Card PIN securely on-device.")
                                font.pixelSize: Theme.fontSizeSmall * 0.8
                                color: Theme.secondaryColor
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
                //End of empty state column

                // SHow/Hide - Freeze/Unfreeze line
                Item {
                    id: physicalCardBottomRow
                    x: Theme.paddingLarge
                    width: parent.width - Theme.paddingLarge * 2
                    height: Math.max(showDetailsAction.implicitHeight,
                                     Math.max(freezeAction.implicitHeight, showPinAction.implicitHeight))
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.paddingLarge

                    Item {
                        width: showDetailsAction.implicitWidth
                        height: showDetailsAction.implicitHeight
                        anchors.left: parent.left
                        visible: physicalCardContainer.hasCard

                        Label {
                            id: showDetailsAction
                            text: page.physicalCardDetailsRevealed ? qsTr("Hide details") : qsTr("Show details")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.togglePhysicalCardDetails()
                        }
                    }

                    Item {
                        width: freezeAction.implicitWidth
                        height: freezeAction.implicitHeight
                        anchors.horizontalCenter: parent.horizontalCenter

                        Label {
                            id: freezeAction
                            text: page.enabledValue ? qsTr("Freeze") : qsTr("Unfreeze")
                            color: page.isOnline ? page.controlColor(page.enabledValue) : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: page.isOnline && !starlingClient.busy
                            onClicked: {
                                var newState = !page.enabledValue
                                page.enabledValue = newState
                                cardData.enabled = newState
                                starlingClient.setCardEnabled(cardData.cardUid, newState)
                            }
                        }
                    }

                    Item {
                        width: showPinAction.implicitWidth
                        height: showPinAction.implicitHeight
                        anchors.right: parent.right
                        visible: physicalCardContainer.hasCard

                        Label {
                            id: showPinAction
                            text: page.physicalCardPinRevealed ? qsTr("Hide PIN") : qsTr("Show PIN")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.togglePhysicalCardPin()
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.physicalCardError.length > 0
                text: page.physicalCardError
                color: Theme.errorColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }
            Item { height: Theme.paddingMedium }

            SectionHeader {
                text: qsTr("Status")
                visible: page.isOnline
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: statusColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)
                visible: page.isOnline

                Column {
                    id: statusColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Column {
                            width: parent.width / 2 - Theme.paddingMedium / 2
                            spacing: Theme.paddingSmall / 2

                            Label {
                                width: parent.width
                                text: qsTr("Cancelled")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                width: parent.width
                                text: page.yesNo(cardData.cancelled || false)
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                            }
                        }

                        Column {
                            width: parent.width / 2 - Theme.paddingMedium / 2
                            spacing: Theme.paddingSmall / 2

                            Label {
                                width: parent.width
                                text: qsTr("Wallet notifications")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                width: parent.width
                                text: page.yesNo(cardData.walletNotificationEnabled || false)
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Controls")
                visible: page.isOnline
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: controlsColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)
                visible: page.isOnline

                Column {
                    id: controlsColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: qsTr("Card present payments")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            visible: !page.editMode
                            width: parent.width
                            text: posEnabledValue ? qsTr("Enabled") : qsTr("Disabled")
                            color: page.controlColor(posEnabledValue)
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        TextSwitch {
                            visible: page.editMode
                            width: parent.width
                            text: qsTr("Card present payments")
                            checked: posEnabledValue
                            automaticCheck: false
                            enabled: !starlingClient.busy

                            onClicked: {
                                posEnabledValue = !posEnabledValue
                                cardData.posEnabled = posEnabledValue
                                starlingClient.setCardPosEnabled(cardData.cardUid, posEnabledValue)
                            }
                        }

                        Label {
                            width: parent.width
                            text: page.posHelpText(posEnabledValue)
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: qsTr("ATM withdrawals")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            visible: !page.editMode
                            width: parent.width
                            text: atmEnabledValue ? qsTr("Enabled") : qsTr("Disabled")
                            color: page.controlColor(atmEnabledValue)
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        TextSwitch {
                            visible: page.editMode
                            width: parent.width
                            text: qsTr("ATM withdrawals")
                            checked: atmEnabledValue
                            automaticCheck: false
                            enabled: !starlingClient.busy

                            onClicked: {
                                atmEnabledValue = !atmEnabledValue
                                cardData.atmEnabled = atmEnabledValue
                                starlingClient.setCardAtmEnabled(cardData.cardUid, atmEnabledValue)
                            }
                        }

                        Label {
                            width: parent.width
                            text: page.atmHelpText(atmEnabledValue)
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: qsTr("Online payments")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            visible: !page.editMode
                            width: parent.width
                            text: onlineEnabledValue ? qsTr("Enabled") : qsTr("Disabled")
                            color: page.controlColor(onlineEnabledValue)
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        TextSwitch {
                            visible: page.editMode
                            width: parent.width
                            text: qsTr("Online payments")
                            checked: onlineEnabledValue
                            automaticCheck: false
                            enabled: !starlingClient.busy

                            onClicked: {
                                onlineEnabledValue = !onlineEnabledValue
                                cardData.onlineEnabled = onlineEnabledValue
                                starlingClient.setCardOnlineEnabled(cardData.cardUid, onlineEnabledValue)
                            }
                        }

                        Label {
                            width: parent.width
                            text: page.onlineHelpText(onlineEnabledValue)
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: qsTr("Mobile wallet")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            visible: !page.editMode
                            width: parent.width
                            text: mobileWalletEnabledValue ? qsTr("Enabled") : qsTr("Disabled")
                            color: page.controlColor(mobileWalletEnabledValue)
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        TextSwitch {
                            visible: page.editMode
                            width: parent.width
                            text: qsTr("Mobile wallet")
                            checked: mobileWalletEnabledValue
                            automaticCheck: false
                            enabled: !starlingClient.busy

                            onClicked: {
                                mobileWalletEnabledValue = !mobileWalletEnabledValue
                                cardData.mobileWalletEnabled = mobileWalletEnabledValue
                                starlingClient.setCardMobileWalletEnabled(cardData.cardUid, mobileWalletEnabledValue)
                            }
                        }

                        Label {
                            width: parent.width
                            text: page.mobileWalletHelpText(mobileWalletEnabledValue)
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: qsTr("Magstripe payments")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            visible: !page.editMode
                            width: parent.width
                            text: magStripeEnabledValue ? qsTr("Enabled") : qsTr("Disabled")
                            color: page.controlColor(magStripeEnabledValue)
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        TextSwitch {
                            visible: page.editMode
                            width: parent.width
                            text: qsTr("Magstripe payments")
                            checked: magStripeEnabledValue
                            automaticCheck: false
                            enabled: !starlingClient.busy

                            onClicked: {
                                if (magStripeEnabledValue) {
                                    magStripeEnabledValue = false
                                    cardData.magStripeEnabled = false
                                    starlingClient.setCardMagStripeEnabled(cardData.cardUid, false)
                                    return
                                }

                                showMagStripeConfirm = true
                            }
                        }

                        Label {
                            width: parent.width
                            text: page.magStripeHelpText(magStripeEnabledValue)
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Gambling")
                visible: page.isOnline
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: gamblingColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)
                visible: page.isOnline

                Column {
                    id: gamblingColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: qsTr("Gambling")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            visible: !page.editMode
                            width: parent.width
                            text: gamblingEnabledValue ? qsTr("Enabled") : qsTr("Disabled")
                            color: page.controlColor(gamblingEnabledValue)
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        TextSwitch {
                            visible: page.editMode
                            width: parent.width
                            text: qsTr("Gambling")
                            checked: gamblingEnabledValue
                            automaticCheck: false
                            enabled: !starlingClient.busy

                            onClicked: {
                                gamblingEnabledValue = !gamblingEnabledValue
                                cardData.gamblingEnabled = gamblingEnabledValue
                                starlingClient.setCardGamblingEnabled(cardData.cardUid, gamblingEnabledValue)
                            }
                        }

                        Label {
                            width: parent.width
                            visible: (cardData.gamblingToBeEnabledAt || "").length > 0
                            text: qsTr("Gambling to be enabled at: %1").arg(cardData.gamblingToBeEnabledAt)
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }
        }
    }

    // Magstripe confrimation overlay
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: page.showMagStripeConfirm
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // block clicks from passing through
            }
        }
        Rectangle {
            id: magstripePopup
            width: Math.min(parent.width - 2 * Theme.horizontalPageMargin,
                            Theme.itemSizeLarge * 4.8)
            height: popupColumn.implicitHeight + 2 * Theme.paddingLarge
            anchors.centerIn: parent
            color: Theme.rgba("black", 0.88)
            border.color: Theme.rgba(Theme.highlightColor, 0.85)
            border.width: 2
            radius: Theme.paddingLarge
            clip: true

            Column {
                id: popupColumn
                x: Theme.paddingLarge
                y: Theme.paddingLarge
                width: parent.width - 2 * Theme.paddingLarge
                spacing: Theme.paddingMedium

                Label {
                    width: parent.width
                    text: qsTr("Unlock Magstripe Payments")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.primaryColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    width: parent.width
                    text: qsTr("You are unlocking magstripe payments for 48 hours. If you make a magstripe payment your 48 hour unlock period will restart. If you don't they will be locked again.")
                    wrapMode: Text.Wrap
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Button {
                        width: (parent.width - Theme.paddingMedium) / 2
                        text: qsTr("Cancel")
                        onClicked: page.showMagStripeConfirm = false
                    }

                    Button {
                        width: (parent.width - Theme.paddingMedium) / 2
                        text: qsTr("Unlock magstripe payments")
                        onClicked: {
                            page.showMagStripeConfirm = false
                            magStripeEnabledValue = true
                            cardData.magStripeEnabled = true
                            starlingClient.setCardMagStripeEnabled(cardData.cardUid, true)
                        }
                    }
                }
            }
        }
    }

    // Consent overlay
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: page.showConsentOverlay
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // block clicks passing through
            }
        }

        Rectangle {
            id: consentPopup
            width: Math.min(parent.width - 2 * Theme.horizontalPageMargin,
                            Theme.itemSizeLarge * 4.8)
            height: consentColumn.implicitHeight + 2 * Theme.paddingLarge
            anchors.centerIn: parent
            color: Theme.rgba("black", 0.88)
            border.color: Theme.rgba(Theme.highlightColor, 0.85)
            border.width: 2
            radius: Theme.paddingLarge
            clip: true

            Column {
                id: consentColumn
                x: Theme.paddingLarge
                y: Theme.paddingLarge
                width: parent.width - 2 * Theme.paddingLarge
                spacing: Theme.paddingMedium

                Label {
                    width: parent.width
                    text: qsTr("Approval Required")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.primaryColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    width: parent.width
                    text: starlingClient.consentMessage.length > 0
                          ? starlingClient.consentMessage
                          : qsTr("This action needs approval in the Starling app.")
                    wrapMode: Text.Wrap
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Button {
                    width: parent.width
                    text: qsTr("Understood")

                    onClicked: {
                        page.showConsentOverlay = false
                        starlingClient.dismissConsentMessage()
                    }
                }
            }
        }
    }

    UnlockOverlay {
        anchors.fill: parent
        visible: starlingClient.locked
        title: qsTr("App locked")
        message: qsTr("Authenticate to access your Starling data.")
        busy: starlingClient.busy
        z: 90
        onUnlockRequested: starlingClient.unlock()
    }
    ActivityCatcher {
        z: 89
        enabled: !starlingClient.locked
    }
}
