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
import Sailfish.Pickers 1.0
import "../components"

Page {
    id: page

    property bool isOnline: starlingClient.online
    property bool editingEmail: false
    property string pageError: ""
    property string emailVerificationMessage: ""
    property bool editingAddress: false
    property string addressUpdateMessage: ""
    property bool editingProfileImage: false
    property string profileImagePath: ""
    property string profileImageError: ""
    property bool profileImagePreviewOpen: false

    function chooseProfileImage() {
        pageStack.push(profileImagePickerComponent)
    }

    function saveProfileImage() {
        page.profileImageError = ""

        if (profileImagePath.length === 0) {
            page.profileImageError = qsTr("Choose an image first.")
            return
        }

        if (!starlingClient.localFileExists(profileImagePath)) {
            page.profileImageError = qsTr("File not found.")
            return
        }

        if (!starlingClient.isSupportedProfileImageFile(profileImagePath)) {
            page.profileImageError = qsTr("Choose an image file.")
            return
        }

        requirePinThen(function() {
            starlingClient.updateProfileImage(profileImagePath)
        })
    }

    function removeProfileImage() {
        requirePinThen(function() {
            starlingClient.deleteProfileImage()
        })
    }

    function todayIsoDate() {
        return new Date().toISOString().substring(0, 10)
    }

    function isValidIsoDate(value) {
        var text = (value || "").trim()

        if (!/^\d{4}-\d{2}-\d{2}$/.test(text))
            return false

        var parts = text.split("-")
        var year = parseInt(parts[0], 10)
        var month = parseInt(parts[1], 10)
        var day = parseInt(parts[2], 10)

        if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31)
            return false

        var date = new Date(year, month - 1, day)

        return date.getFullYear() === year
                && date.getMonth() === month - 1
                && date.getDate() === day
    }

    function prefillAddressFields() {
        addressLine1Field.text = starlingClient.currentAddress.line1 || ""
        addressLine2Field.text = starlingClient.currentAddress.line2 || ""
        addressLine3Field.text = starlingClient.currentAddress.line3 || ""
        postTownField.text = starlingClient.currentAddress.postTown || ""
        postCodeField.text = starlingClient.currentAddress.postCode || ""
        countryCodeField.text = starlingClient.currentAddress.countryCode || "GB"
        fromDateField.text = starlingClient.currentAddress.from || ""
    }

    function saveAddress() {
        page.pageError = ""

        if (addressLine1Field.text.trim().length === 0) {
            page.pageError = qsTr("Address line 1 is required.")
            return
        }

        if (postTownField.text.trim().length === 0) {
            page.pageError = qsTr("Town/city is required.")
            return
        }

        if (postCodeField.text.trim().length === 0) {
            page.pageError = qsTr("Postcode is required.")
            return
        }

        if (countryCodeField.text.trim().length !== 2) {
            page.pageError = qsTr("Country code must be two letters, for example GB.")
            return
        }

        if (!page.isValidIsoDate(fromDateField.text.trim())) {
            page.pageError = qsTr("Enter a valid move-in date in YYYY-MM-DD format.")
            return
        }

        requirePinThen(function() {
            starlingClient.updateAccountHolderAddress(
                        addressLine1Field.text.trim(),
                        addressLine2Field.text.trim(),
                        addressLine3Field.text.trim(),
                        postTownField.text.trim(),
                        postCodeField.text.trim(),
                        countryCodeField.text.trim(),
                        fromDateField.text.trim())
        })
    }

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
                width: parent.width - 2 * x
                height: profileColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: profileColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Item {
                        width: parent.width
                        height: Math.max(titleLabel.height, editProfileImageSwitch.height)

                        Label {
                            id: titleLabel
                            anchors.left: parent.left
                            anchors.right: editProfileImageSwitch.left
                            anchors.rightMargin: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter

                            text: qsTr("Profile image")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            truncationMode: TruncationMode.Fade
                        }

                        TextSwitch {
                            id: editProfileImageSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            width: Theme.itemSizeHuge
                            text: qsTr("Edit")
                            checked: page.editingProfileImage
                            enabled: !starlingClient.busy

                            onCheckedChanged: {
                                page.editingProfileImage = checked

                                if (!checked) {
                                    page.profileImageError = ""
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: profileImage.visible ? profileImage.height : 0
                        visible: starlingClient.profileImageAvailable

                        Image {
                            id: profileImage
                            width: Theme.itemSizeHuge
                            height: width
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: starlingClient.profileImageAvailable
                            source: starlingClient.profileImageAvailable
                                    ? "file://" + starlingClient.profileImagePath
                                    : ""
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                        }

                        MouseArea {
                            anchors.fill: profileImage
                            enabled: starlingClient.profileImageAvailable
                            onClicked: page.profileImagePreviewOpen = true
                        }
                    }

                    Label {
                        width: parent.width
                        visible: !starlingClient.profileImageAvailable
                        text: qsTr("No profile image found.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Button {
                        width: parent.width
                        visible: page.editingProfileImage
                        enabled: !starlingClient.busy
                        text: qsTr("Choose new image")
                        onClicked: page.chooseProfileImage()
                    }

                    Label {
                        width: parent.width
                        visible: page.editingProfileImage && page.profileImagePath.length > 0
                        text: page.profileImagePath
                        color: Theme.secondaryColor
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall
                        visible: page.editingProfileImage

                        Button {
                            width: (parent.width - Theme.paddingSmall) / 2
                            enabled: !starlingClient.busy
                            text: qsTr("Save image")
                            onClicked: page.saveProfileImage()
                        }

                        Button {
                            width: (parent.width - Theme.paddingSmall) / 2
                            enabled: !starlingClient.busy && starlingClient.profileImageAvailable
                            text: qsTr("Remove image")
                            onClicked: page.removeProfileImage()
                        }
                    }

                    Label {
                        width: parent.width
                        visible: page.profileImageError.length > 0
                        text: page.profileImageError
                        color: Theme.errorColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
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
                        visible: hasText(starlingClient.postalAddress) || page.editingAddress

                        Label {
                            width: parent.width
                            text: qsTr("Postal address")
                            color: Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            width: parent.width
                            visible: !page.editingAddress
                            text: starlingClient.postalAddress || ""
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                        }

                        TextField {
                            id: addressLine1Field
                            width: parent.width
                            visible: page.editingAddress
                            label: qsTr("Address line 1")
                            enabled: !starlingClient.busy
                            onTextChanged: page.pageError = ""
                        }

                        TextField {
                            id: addressLine2Field
                            width: parent.width
                            visible: page.editingAddress
                            label: qsTr("Address line 2")
                            enabled: !starlingClient.busy
                            onTextChanged: page.pageError = ""
                        }

                        TextField {
                            id: addressLine3Field
                            width: parent.width
                            visible: page.editingAddress
                            label: qsTr("Address line 3")
                            enabled: !starlingClient.busy
                            onTextChanged: page.pageError = ""
                        }

                        TextField {
                            id: postTownField
                            width: parent.width
                            visible: page.editingAddress
                            label: qsTr("Town/city")
                            enabled: !starlingClient.busy
                            onTextChanged: page.pageError = ""
                        }

                        TextField {
                            id: postCodeField
                            width: parent.width
                            visible: page.editingAddress
                            label: qsTr("Postcode")
                            enabled: !starlingClient.busy
                            onTextChanged: page.pageError = ""
                        }

                        TextField {
                            id: countryCodeField
                            width: parent.width
                            visible: page.editingAddress
                            label: qsTr("Country code")
                            placeholderText: qsTr("GB")
                            enabled: !starlingClient.busy
                            onTextChanged: page.pageError = ""
                        }

                        TextField {
                            id: fromDateField
                            width: parent.width
                            visible: page.editingAddress
                            label: qsTr("Moved in on")
                            placeholderText: qsTr("YYYY-MM-DD")
                            enabled: !starlingClient.busy
                            inputMethodHints: Qt.ImhDigitsOnly

                            property bool formatting: false

                            onTextChanged: {
                                page.pageError = ""

                                if (formatting)
                                    return

                                formatting = true

                                var digits = text.replace(/[^0-9]/g, "")
                                if (digits.length > 8)
                                    digits = digits.substring(0, 8)

                                var formatted = digits
                                if (digits.length > 4)
                                    formatted = digits.substring(0, 4) + "-" + digits.substring(4)
                                if (digits.length > 6)
                                    formatted = digits.substring(0, 4) + "-" + digits.substring(4, 6) + "-" + digits.substring(6)

                                text = formatted
                                cursorPosition = text.length

                                formatting = false
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingSmall

                            TextSwitch {
                                id: editAddressSwitch
                                width: parent.width - Theme.itemSizeLarge - Theme.paddingSmall
                                text: qsTr("Edit address")
                                checked: page.editingAddress
                                enabled: page.canEditEmail() && !starlingClient.busy

                                onCheckedChanged: {
                                    page.editingAddress = checked
                                    page.addressUpdateMessage = ""

                                    if (checked) {
                                        page.prefillAddressFields()

//                                        if (fromDateField.text.length === 0)
//                                            fromDateField.text = page.todayIsoDate()
                                    }
                                }
                            }

                            Button {
                                width: Theme.itemSizeLarge
                                visible: page.editingAddress
                                enabled: page.canEditEmail() && !starlingClient.busy
                                text: qsTr("Save")
                                onClicked: page.saveAddress()
                            }
                        }
                    }

                    Rectangle {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        height: addressUpdateColumn.height + 2 * Theme.paddingMedium
                        visible: page.addressUpdateMessage.length > 0

                        radius: Theme.paddingMedium
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                        border.width: 1
                        border.color: Theme.rgba(Theme.highlightColor, 0.35)

                        Column {
                            id: addressUpdateColumn
                            x: Theme.paddingMedium
                            y: Theme.paddingMedium
                            width: parent.width - 2 * Theme.paddingMedium
                            spacing: Theme.paddingMedium

                            Label {
                                width: parent.width
                                text: qsTr("Address update")
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                            }

                            Label {
                                width: parent.width
                                text: page.addressUpdateMessage
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                            }

                            Button {
                                width: parent.width
                                text: qsTr("OK")
                                onClicked: page.addressUpdateMessage = ""
                            }
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

    Component {
        id: profileImagePickerComponent

        FilePickerPage {
            title: qsTr("Select profile image")
            nameFilters: [
                "*.jpg",
                "*.jpeg",
                "*.png",
                "*.webp"
            ]

            onSelectedContentPropertiesChanged: {
                if (selectedContentProperties && selectedContentProperties.filePath) {
                    page.profileImagePath = selectedContentProperties.filePath
                    page.profileImageError = ""
                    page.editingProfileImage = true
                    editProfileImageSwitch.checked = true
                }
            }
        }
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

        onAccountHolderAddressUpdated: {
            page.editingAddress = false
            editAddressSwitch.checked = false
            page.pageError = ""

            page.addressUpdateMessage =
                    qsTr("Your address update has been submitted. Starling may review or confirm the change before it fully appears on your account.")
        }

        onAccountHolderBasicChanged: {
            if ((starlingClient.accountHolderBasic.accountHolderUid || "").length > 0)
                starlingClient.refreshProfileImage()
        }

        onProfileImageUpdated: {
            page.editingProfileImage = false
            editProfileImageSwitch.checked = false
            page.profileImagePath = ""
            page.profileImageError = ""
            page.profileImagePreviewOpen = false
        }

        onProfileImageDeleted: {
            page.editingProfileImage = false
            editProfileImageSwitch.checked = false
            page.profileImagePath = ""
            page.profileImageError = ""
            page.profileImagePreviewOpen = false
        }
    }

    Item {
        anchors.fill: parent
        visible: page.profileImagePreviewOpen
        z: 999

        Rectangle {
            anchors.fill: parent
            color: Theme.rgba(Theme.overlayBackgroundColor, 0.90)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: page.profileImagePreviewOpen = false
        }

        Image {
            anchors.centerIn: parent
            width: Math.min(parent.width - 2 * Theme.horizontalPageMargin,
                            sourceSize.width > 0 ? sourceSize.width : parent.width - 2 * Theme.horizontalPageMargin)
            height: Math.min(parent.height - 2 * Theme.paddingLarge,
                             sourceSize.height > 0 ? sourceSize.height : parent.height - 2 * Theme.paddingLarge)
            source: starlingClient.profileImageAvailable
                    ? "file://" + starlingClient.profileImagePath
                    : ""
            fillMode: Image.PreserveAspectFit
            cache: false
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
