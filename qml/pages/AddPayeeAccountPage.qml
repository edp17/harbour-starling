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

    property string payeeUid: ""
    property bool submitting: false
    property bool readyForContent: !starlingClient.locked

    function trimmed(v) {
        return (v === undefined || v === null) ? "" : String(v).trim()
    }

    function digitsOnly(v) {
        return trimmed(v).replace(/[^0-9]/g, "")
    }

    function formattedSortCode(v) {
        var d = digitsOnly(v)
        if (d.length <= 2)
            return d
        if (d.length <= 4)
            return d.slice(0, 2) + "-" + d.slice(2)
        return d.slice(0, 2) + "-" + d.slice(2, 4) + "-" + d.slice(4, 6)
    }

    function autoDescription() {
        var acc = digitsOnly(accountNumberField.text)
        if (acc.length >= 4)
            return qsTr("Account ending %1").arg(acc.slice(acc.length - 4))
        return qsTr("Bank account")
    }

    function canSubmit() {
        return !submitting
                && payeeUid.length > 0
                && countryCodeField.currentIndex >= 0
                && digitsOnly(accountNumberField.text).length > 0
                && digitsOnly(sortCodeField.text).length === 6
    }

    Connections {
        target: starlingClient

        onStatusChanged: {
            if (!page.submitting)
                return

            if (starlingClient.status.indexOf("account") !== -1 &&
                    (starlingClient.status.indexOf("created") !== -1 ||
                     starlingClient.status.indexOf("added") !== -1 ||
                     starlingClient.status.indexOf("Account created") !== -1 ||
                     starlingClient.status.indexOf("Account added") !== -1)) {
                page.submitting = false
                starlingClient.refreshPayeeDetail(page.payeeUid)
                pageStack.pop()
            } else if (!starlingClient.busy &&
                       starlingClient.status.indexOf("error") !== -1) {
                page.submitting = false
            }
        }

        onBusyChanged: {
            if (!starlingClient.busy && page.submitting) {
                // Leave final decision to statusChanged, but if busy dropped without
                // a matching success phrase, allow user to try again.
                if (starlingClient.status.indexOf("created") === -1 &&
                        starlingClient.status.indexOf("added") === -1 &&
                        starlingClient.status.indexOf("Created") === -1 &&
                        starlingClient.status.indexOf("Added") === -1) {
                    page.submitting = false
                }
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
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Add account")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("Add a bank account to this payee.")
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
            }

            ComboBox {
                id: countryCodeField
                width: parent.width
                label: qsTr("Account country")
                currentIndex: 0
                description: qsTr("Country of the bank account")
                menu: ContextMenu {
                    MenuItem { text: "GB" }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("Account number")
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            TextField {
                id: accountNumberField
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                label: qsTr("Account number")
                placeholderText: qsTr("Required")
                inputMethodHints: Qt.ImhDigitsOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: sortCodeField.focus = true

                onTextChanged: {
                    var d = digitsOnly(text)
                    if (text !== d)
                        text = d
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("Sort code")
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            TextField {
                id: sortCodeField
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                label: qsTr("Sort code")
                placeholderText: qsTr("Required")
                inputMethodHints: Qt.ImhDigitsOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.enabled: page.canSubmit()
                EnterKey.onClicked: addButton.clicked()

                onTextChanged: {
                    var f = formattedSortCode(text)
                    if (text !== f)
                        text = f
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("The account will be added as the default account for this payee.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
            }

            Button {
                id: addButton
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: page.submitting || starlingClient.busy ? qsTr("Adding…") : qsTr("Add account")
                enabled: page.canSubmit()

                onClicked: {
                    if (!page.canSubmit())
                        return

                    page.submitting = true

                    starlingClient.createPayeeAccount(
                        page.payeeUid,
                        autoDescription(),
                        true,                              // defaultAccount
                        countryCodeField.currentItem ? countryCodeField.currentItem.text : "GB",           // countryCode
                        digitsOnly(accountNumberField.text),
                        digitsOnly(sortCodeField.text),
                        "SORT_CODE",                      // bankIdentifierType
                        ""                                // secondaryIdentifier
                    )
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
        z: 997
        enabled: !starlingClient.locked
    }
}
