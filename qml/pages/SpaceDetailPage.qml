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

    property var space: ({})
    property bool transferRequested: false
    property bool deleteRequested: false
    property string pageError: ""

    function amountToMinorUnits(text) {
        var cleaned = (text || "").trim().replace(",", ".")
        var amount = parseFloat(cleaned)

        if (isNaN(amount) || amount <= 0)
            return -1

        return Math.round(amount * 100)
    }

    function deleteGoal() {
        deleteRequested = true
        requirePinThen(function() {
            starlingClient.deleteSavingsGoal(page.space.spaceUid)
        })
    }

    function requirePinThen(action) {
        pinActionRunner.pendingAction = action
        starlingClient.requestPinConfirmation()
    }

    function addMoney() {
        page.pageError = ""

        var minor = page.amountToMinorUnits(amountField.text)

        if (minor <= 0) {
            page.pageError = qsTr("Enter a valid amount.")
            return
        }

        if (minor > starlingClient.availableBalanceMinorUnits) {
            page.pageError = qsTr("Not enough available balance.")
            return
        }

        transferRequested = true
        requirePinThen(function() {
            starlingClient.addMoneyToSavingsGoal(page.space.spaceUid, amountField.text.trim())
        })
    }

    function withdrawMoney() {
        page.pageError = ""

        var minor = page.amountToMinorUnits(amountField.text)
        var potBalance = page.space.balanceMinorUnits || 0

        if (minor <= 0) {
            starlingClient.setStatus(qsTr("Enter a valid amount."))
            return
        }

        if (minor > potBalance) {
            page.pageError = qsTr("This savings goal does not have enough money.")
            return
        }

        transferRequested = true
        requirePinThen(function() {
            starlingClient.withdrawMoneyFromSavingsGoal(page.space.spaceUid, amountField.text.trim())
        })
    }

    function valueOrDash(value) {
        return value && value.length > 0 ? value : "-"
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Space details")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: summaryColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: summaryColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: page.valueOrDash(page.space.name)
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: page.valueOrDash(page.space.balance)
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }

                    Label {
                        width: parent.width
                        visible: page.space.target && page.space.target.length > 0
                        text: qsTr("Target: %1").arg(page.space.target)
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: roundUpColumn.height + 2 * Theme.paddingMedium
                visible: true

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: roundUpColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Round-up")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        text: starlingClient.roundUp.active === true
                              && starlingClient.roundUp.roundUpGoalUid === page.space.spaceUid
                              ? qsTr("Active for this savings goal")
                              : qsTr("Not active for this savings goal")
                        color: starlingClient.roundUp.active === true
                               && starlingClient.roundUp.roundUpGoalUid === page.space.spaceUid
                               ? Theme.highlightColor
                               : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        visible: starlingClient.roundUp.active === true
                                 && starlingClient.roundUp.roundUpGoalUid === page.space.spaceUid
                        text: qsTr("Multiplier: %1x").arg(starlingClient.roundUp.roundUpMultiplier || 1)
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Button {
                        width: parent.width
                        text: qsTr("Manage round-up")
                        onClicked: pageStack.push(Qt.resolvedUrl("RoundUpPage.qml"))
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
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
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Type: %1").arg(page.valueOrDash(page.space.type))
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("State: %1").arg(page.valueOrDash(page.space.state))
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Currency: %1").arg(page.valueOrDash(page.space.currency))
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Created: %1").arg(page.valueOrDash(page.space.createdAt))
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Updated: %1").arg(page.valueOrDash(page.space.updatedAt))
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Rectangle {
                // Actions card
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: actionColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.primaryColor, 0.15)

                Column {
                    id: actionColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: qsTr("Actions")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Move money in or out of this savings goal.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: amountField
                        width: parent.width
                        label: qsTr("Amount")
                        placeholderText: qsTr("10.00")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        onTextChanged: page.pageError = ""
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Button {
                            width: (parent.width - Theme.paddingMedium) / 2
                            enabled: amountField.text.trim().length > 0 && !starlingClient.busy
                            text: qsTr("Add")
                            onClicked: page.addMoney()
                        }

                        Button {
                            width: (parent.width - Theme.paddingMedium) / 2
                            enabled: amountField.text.trim().length > 0 && !starlingClient.busy
                            text: qsTr("Withdraw")
                            onClicked: page.withdrawMoney()
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.pageError.length > 0 || starlingClient.status.length > 0
                text: page.pageError.length > 0 ? page.pageError : starlingClient.status
                color: page.pageError.length > 0 ? Theme.errorColor : Theme.secondaryColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            Rectangle {
                // Delete card
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: deleteColumn.height + 2 * Theme.paddingMedium

                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.errorColor, 0.25)
                border.width: 1
                border.color: Theme.rgba(Theme.errorColor, 0.15)

                Column {
                    id: deleteColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: qsTr("Delete")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Delete this savings goal when you no longer need it.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: page.space.balanceMinorUnits > 0
                        text: qsTr("Withdraw all money before deleting this savings goal.")
                        color: Theme.errorColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Button {
                        width: parent.width
                        enabled: !starlingClient.busy
                                 && (!page.space.balanceMinorUnits
                                     || page.space.balanceMinorUnits <= 0)
                        text: qsTr("Delete savings goal")
                        onClicked: page.deleteGoal()
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
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

        onSavingsGoalTransferCompleted: {
            if (page.transferRequested) {
                page.transferRequested = false
                pageStack.pop()
            }
        }

        onSavingsGoalDeleted: {
            if (page.deleteRequested) {
                page.deleteRequested = false
                pageStack.pop()
            }
        }
    }

    Component.onCompleted: {
        starlingClient.refreshRoundUp()
    }
}
