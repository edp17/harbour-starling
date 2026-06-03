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

    property bool settingsUnlocked: !starlingClient.locked
    onSettingsUnlockedChanged: {
        if (settingsUnlocked) {
            syncTokenField()
            syncAutoLockField()
        } else {
            tokenField.text = ""
            payeeWriteTokenField.text = ""
            apiKeyIdField.text = ""
            privateApiKeyPemField.text = ""
        }
    }
    property string newPinValue: ""
    property string confirmPinValue: ""
    property string currentPinValue: ""
    property bool showPinInfoOverlay: false
    property string pinInfoOverlayText: ""

    function reloadSecureFields() {
        starlingClient.loadToken()
        starlingClient.loadPayeeWriteToken()
        starlingClient.loadApiKeyId()
        starlingClient.loadPrivateApiKeyPem()

        syncTokenField()
    }

    function syncTokenField() {
        tokenField.text = settingsUnlocked ? starlingClient.token : ""
        payeeWriteTokenField.text = settingsUnlocked ? starlingClient.payeeWriteToken : ""
        apiKeyIdField.text = settingsUnlocked ? starlingClient.apiKeyId : ""
        privateApiKeyPemField.text = settingsUnlocked ? starlingClient.privateApiKeyPem : ""
    }

    function syncAutoLockField() {
        var values = [1, 2, 3, 4, 5, 10, 15, 30]
        var current = starlingClient.autoLockMinutes
        for (var i = 0; i < values.length; ++i) {
            if (values[i] === current) {
                autoLockCombo.currentIndex = i
                return
            }
        }
        autoLockCombo.currentIndex = 1 // default 2 minutes
    }

    function requirePinThen(action) {
        pinActionRunner.pendingAction = action
        starlingClient.requestPinConfirmation()
    }

    function requirePinForPinChange() {
        pinChangeRunner.changePinPending = true
        starlingClient.requestPinConfirmation()
    }

    QtObject {
        id: pinActionRunner
        property var pendingAction: null
    }

    QtObject {
        id: pinChangeRunner
        property bool changePinPending: false
    }

    Timer {
        id: pinConfirmWatcher
        interval: 100
        repeat: true
        running: false

        property var action: null

        onTriggered: {
            if (!starlingClient.pinPromptVisible && !starlingClient.pinConfirmationPending) {
                running = false
                if (action) {
                    action()
                    action = null
                }
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            starlingClient.clearPinSettingsError()
            if (!starlingClient.locked) {
                reloadSecureFields()
                syncAutoLockField()
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("About security")
                onClicked: pageStack.push(Qt.resolvedUrl("SecurityPage.qml"))
            }
        }

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Settings")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: notesColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: notesColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
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
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        text: qsTr("All sensitive data, including tokens and keys, is stored securely using Sailfish Secrets and protected by your app PIN.")
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: appLockColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: appLockColumn
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

                    TextSwitch {
                        width: parent.width
                        text: qsTr("Lock immediately in background")
                        description: qsTr("When enabled, the app locks as soon as it goes to the background. When disabled, it remains unlocked until the inactivity timer expires.")
                        checked: starlingClient.lockOnBackground
                        automaticCheck: false
                        onClicked: {
                            starlingClient.lockOnBackground = !starlingClient.lockOnBackground
                        }
                    }

                    ComboBox {
                        id: autoLockCombo
                        width: parent.width
                        label: qsTr("Auto-lock after inactivity")
                        menu: ContextMenu {
                            MenuItem { text: qsTr("1 minute") }
                            MenuItem { text: qsTr("2 minutes") }
                            MenuItem { text: qsTr("3 minutes") }
                            MenuItem { text: qsTr("4 minutes") }
                            MenuItem { text: qsTr("5 minutes") }
                            MenuItem { text: qsTr("10 minutes") }
                            MenuItem { text: qsTr("15 minutes") }
                            MenuItem { text: qsTr("30 minutes") }
                        }
                        onCurrentIndexChanged: {
                            var values = [1, 2, 3, 4, 5, 10, 15, 30]
                            if (currentIndex >= 0 && currentIndex < values.length)
                                starlingClient.autoLockMinutes = values[currentIndex]
                        }
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        text: starlingClient.lockOnBackground
                              ? qsTr("The inactivity timeout applies while the app is in use. Backgrounding locks it immediately.")
                              : qsTr("The app locks after this amount of inactivity, even if it is in the background.")
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: appPinColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: appPinColumn
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
                        text: qsTr("An app PIN protects access to the app and is required to unlock it.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.pinEnabled
                        text: qsTr("To change the app PIN, enter the current PIN first.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    TextField {
                        id: newPinField
                        width: parent.width
                        label: qsTr("New PIN")
                        placeholderText: qsTr("4 to 8 digits")
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                        onTextChanged: {
                            if (starlingClient.pinSettingsError.length > 0)
                                starlingClient.clearPinSettingsError()
                        }
                    }

                    TextField {
                        id: confirmPinField
                        width: parent.width
                        label: qsTr("Confirm PIN")
                        placeholderText: qsTr("Repeat PIN")
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                        onTextChanged: {
                            if (starlingClient.pinSettingsError.length > 0)
                                starlingClient.clearPinSettingsError()
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

                    Button {
                        width: parent.width
                        text: starlingClient.pinEnabled ? qsTr("Change app PIN") : qsTr("Enable app PIN")
                        onClicked: {
                            starlingClient.clearPinSettingsError()
                            if (starlingClient.pinEnabled) {
                                requirePinForPinChange()
                                return
                            }
                            var ok = starlingClient.setAppPin(newPinField.text, confirmPinField.text)
                            if (ok) {
                                newPinField.text = ""
                                confirmPinField.text = ""
                                pinInfoOverlayText = qsTr("App PIN enabled.\n\nTo change it later, enter the current PIN first.")
                                showPinInfoOverlay = true
                            }
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: accessTokensColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: accessTokensColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Access tokens")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        text: qsTr("Manage authentication tokens used to access your Starling account and perform actions such as loading data or submitting payments.")
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Item {
                        width: parent.width
                        height: settingsUnlocked ? 0 : lockColumn.height + Theme.paddingLarge
                        visible: !settingsUnlocked

                        Column {
                            id: lockColumn
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: Theme.paddingLarge

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                color: Theme.primaryColor
                                text: qsTr("Settings are locked. Unlock to view or change stored credentials.")
                            }

                            BusyIndicator {
                                anchors.horizontalCenter: parent.horizontalCenter
                                running: starlingClient.busy
                                visible: running
                                size: BusyIndicatorSize.Medium
                            }

                            Button {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Unlock settings")
                                enabled: !starlingClient.busy
                                onClicked: {
                                    starlingClient.unlock()
                                    syncTokenField()
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: settingsUnlocked

                        Item {
                            id: tokenEditor
                            width: parent.width
                            height: tokenLabel.height + tokenBackground.height + Theme.paddingSmall

                            Label {
                                id: tokenLabel
                                width: parent.width
                                text: qsTr("Personal access token")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Rectangle {
                                id: tokenBackground
                                anchors.top: tokenLabel.bottom
                                anchors.topMargin: Theme.paddingSmall
                                width: parent.width
                                height: Theme.itemSizeMedium
                                radius: 8
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.rgba(Theme.primaryColor, 0.25)
                            }

                            TextInput {
                                id: tokenField
                                parent: tokenBackground
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.paddingMedium
                                anchors.rightMargin: Theme.paddingMedium
                                color: Theme.primaryColor
                                selectionColor: Theme.highlightColor
                                selectedTextColor: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                echoMode: TextInput.Password
                                clip: true
                            }
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            text: qsTr("Used for general account access, including balances, transactions and payees.")
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Button {
                                width: (parent.width - Theme.paddingMedium) / 2
                                text: qsTr("Save main token")
                                onClicked: {
                                    requirePinThen(function() {
                                        starlingClient.token = tokenField.text
                                        starlingClient.saveToken()
                                        syncTokenField()
                                    })
                                }
                            }

                            Button {
                                width: (parent.width - Theme.paddingMedium) / 2
                                text: qsTr("Clear")
                                onClicked: {
                                    requirePinThen(function() {
                                        tokenField.text = ""
                                        starlingClient.clearToken()
                                    })
                                }
                            }
                        }

                        Item {
                            id: payeeWriteTokenEditor
                            width: parent.width
                            height: payeeWriteTokenLabel.height + payeeWriteTokenBackground.height + Theme.paddingSmall

                            Label {
                                id: payeeWriteTokenLabel
                                width: parent.width
                                text: qsTr("Payee write token")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Rectangle {
                                id: payeeWriteTokenBackground
                                anchors.top: payeeWriteTokenLabel.bottom
                                anchors.topMargin: Theme.paddingSmall
                                width: parent.width
                                height: Theme.itemSizeMedium
                                radius: 8
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.rgba(Theme.primaryColor, 0.25)
                            }

                            TextInput {
                                id: payeeWriteTokenField
                                parent: payeeWriteTokenBackground
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.paddingMedium
                                anchors.rightMargin: Theme.paddingMedium
                                color: Theme.primaryColor
                                selectionColor: Theme.highlightColor
                                selectedTextColor: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                echoMode: TextInput.Password
                                clip: true
                            }
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            text: qsTr("Required to create, update or delete payees.")
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Button {
                                width: (parent.width - Theme.paddingMedium) / 2
                                text: qsTr("Save payee token")
                                onClicked: {
                                    requirePinThen(function() {
                                        starlingClient.payeeWriteToken = payeeWriteTokenField.text
                                        starlingClient.savePayeeWriteToken()
                                    })
                                }
                            }

                            Button {
                                width: (parent.width - Theme.paddingMedium) / 2
                                text: qsTr("Clear")
                                onClicked: {
                                    requirePinThen(function() {
                                        payeeWriteTokenField.text = ""
                                        starlingClient.clearPayeeWriteToken()
                                    })
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: paymentSigningColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: paymentSigningColumn
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

                    Item {
                        id: apiKeyIdEditor
                        width: parent.width
                        height: apiKeyIdLabel.height + apiKeyIdBackground.height + Theme.paddingSmall

                        Label {
                            id: apiKeyIdLabel
                            width: parent.width
                            text: qsTr("API key ID")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Rectangle {
                            id: apiKeyIdBackground
                            anchors.top: apiKeyIdLabel.bottom
                            anchors.topMargin: Theme.paddingSmall
                            width: parent.width
                            height: Theme.itemSizeMedium
                            radius: 8
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.rgba(Theme.primaryColor, 0.25)
                        }

                        TextInput {
                            id: apiKeyIdField
                            parent: apiKeyIdBackground
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.rightMargin: Theme.paddingMedium
                            color: Theme.primaryColor
                            selectionColor: Theme.highlightColor
                            selectedTextColor: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            clip: true
                        }
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        text: qsTr("The key ID provided by Starling when you upload your public API key.")
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Button {
                            width: (parent.width - Theme.paddingMedium) / 2
                            text: qsTr("Save API key ID")
                            onClicked: {
                                requirePinThen(function() {
                                    starlingClient.apiKeyId = apiKeyIdField.text
                                    starlingClient.saveApiKeyId()
                                    syncTokenField()
                                })
                            }
                        }

                        Button {
                            width: (parent.width - Theme.paddingMedium) / 2
                            text: qsTr("Clear")
                            onClicked: {
                                requirePinThen(function() {
                                    apiKeyIdField.text = ""
                                    starlingClient.clearApiKeyId()
                                })
                            }
                        }
                    }

                    Item {
                        id: privateApiKeyEditor
                        width: parent.width
                        height: privateApiKeyLabel.height + privateApiKeyBackground.height + Theme.paddingSmall

                        Label {
                            id: privateApiKeyLabel
                            width: parent.width
                            text: qsTr("Private API key (PEM)")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Rectangle {
                            id: privateApiKeyBackground
                            anchors.top: privateApiKeyLabel.bottom
                            anchors.topMargin: Theme.paddingSmall
                            width: parent.width
                            height: Theme.itemSizeHuge * 2.2
                            radius: 8
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.rgba(Theme.primaryColor, 0.25)
                        }

                        TextEdit {
                            id: privateApiKeyPemField
                            parent: privateApiKeyBackground
                            anchors.fill: parent
                            anchors.margins: Theme.paddingMedium
                            color: Theme.primaryColor
                            selectionColor: Theme.highlightColor
                            selectedTextColor: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            wrapMode: TextEdit.Wrap
                            clip: true
                        }
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        text: qsTr("Your private RSA key in PEM format. This is used to sign payment requests.")
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Button {
                            width: (parent.width - Theme.paddingMedium) / 2
                            text: qsTr("Save private key")
                            onClicked: {
                                requirePinThen(function() {
                                    starlingClient.privateApiKeyPem = privateApiKeyPemField.text
                                    starlingClient.savePrivateApiKeyPem()
                                    syncTokenField()
                                })
                            }
                        }

                        Button {
                            width: (parent.width - Theme.paddingMedium) / 2
                            text: qsTr("Clear")
                            onClicked: {
                                requirePinThen(function() {
                                    privateApiKeyPemField.text = ""
                                    starlingClient.clearPrivateApiKeyPem()
                                })
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        text: qsTr("These keys are required to sign payment requests. Without them, payments cannot be submitted.")
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: dangerZoneColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.errorColor, 0.25)

                Column {
                    id: dangerZoneColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Danger zone")
                        color: Theme.errorColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        text: qsTr("Deletes all locally stored data, including tokens, API keys, physical card details and app PIN.")
                    }

                    Button {
                        width: parent.width
                        text: qsTr("Factory reset app")
                        onClicked: {
                            requirePinThen(function() {
                                if (starlingClient.factoryResetAfterConfirmation()) {
                                    tokenField.text = ""
                                    payeeWriteTokenField.text = ""
                                    apiKeyIdField.text = ""
                                    privateApiKeyPemField.text = ""
                                    pageStack.pop()
                                }
                            })
                        }
                    }
                }
            }

            BusyIndicator {
                x: Theme.horizontalPageMargin
                size: BusyIndicatorSize.Medium
                running: starlingClient.busy && settingsUnlocked
                visible: running
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }
        }
    }

    Connections {
        target: starlingClient

        function onLockedChanged() {
            if (!starlingClient.locked) {
                reloadSecureFields()
                syncAutoLockField()
                    } else {
                tokenField.text = ""
                payeeWriteTokenField.text = ""
                apiKeyIdField.text = ""
                privateApiKeyPemField.text = ""
            }
        }

        function onTokenChanged() {
            if (!starlingClient.locked) {
                tokenField.text = starlingClient.token
            }
        }

        function onPayeeWriteTokenChanged() {
            if (!starlingClient.locked) {
                payeeWriteTokenField.text = starlingClient.payeeWriteToken
            }
        }

        function onApiKeyIdChanged() {
            if (!starlingClient.locked) {
                apiKeyIdField.text = starlingClient.apiKeyId
            }
        }

        function onPrivateApiKeyPemChanged() {
            if (!starlingClient.locked) {
                privateApiKeyPemField.text = starlingClient.privateApiKeyPem
            }
        }

        onPinConfirmed: {
            if (pinActionRunner.pendingAction) {
                var action = pinActionRunner.pendingAction
                pinActionRunner.pendingAction = null
                action()
                return
            }

            if (pinChangeRunner.changePinPending) {
                pinChangeRunner.changePinPending = false

                var ok = starlingClient.changeAppPinAfterConfirmation(newPinField.text,
                                                      confirmPinField.text)

                if (ok) {
                    newPinField.text = ""
                    confirmPinField.text = ""

                    pinInfoOverlayText = qsTr("App PIN updated.\n\nTo change it later, enter the current PIN first.")
                    showPinInfoOverlay = true
                }
            }
        }
    }

    Component.onCompleted: {
        starlingClient.clearPinSettingsError()
        syncAutoLockField()

        if (!starlingClient.locked) {
            reloadSecureFields()
        } else {
            tokenField.text = ""
            payeeWriteTokenField.text = ""
            apiKeyIdField.text = ""
            privateApiKeyPemField.text = ""
        }
    }

    Item {
        anchors.fill: parent
        visible: showPinInfoOverlay
        enabled: visible
        z: 120

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // swallow input
            }
        }

        Rectangle {
            id: pinInfoPanel
            width: parent.width - 2 * Theme.horizontalPageMargin
            anchors.centerIn: parent
            radius: Theme.paddingMedium
            color: Theme.highlightDimmerColor
            border.width: 2
            border.color: Theme.rgba(Theme.primaryColor, 0.65)
            height: pinInfoColumn.height + 2 * Theme.paddingLarge

            Column {
                id: pinInfoColumn
                x: Theme.paddingLarge
                y: Theme.paddingLarge
                width: parent.width - 2 * Theme.paddingLarge
                spacing: Theme.paddingMedium

                Label {
                    width: parent.width
                    text: qsTr("App PIN")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.primaryColor
                }

                Label {
                    width: parent.width
                    text: pinInfoOverlayText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("OK")
                    onClicked: showPinInfoOverlay = false
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
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }
    ActivityCatcher {
        z: 999
        enabled: !starlingClient.locked
    }
}
