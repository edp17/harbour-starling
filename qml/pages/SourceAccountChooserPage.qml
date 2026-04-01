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
    property string payeeName: ""
    property var accountData: ({})
    property bool readyForContent: !starlingClient.locked

    function valueOrEmpty(v) {
        return (v === undefined || v === null) ? "" : String(v)
    }

    Component.onCompleted: {
        if ((starlingClient.sourceAccounts || []).length === 0)
            starlingClient.discoverAccount()
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
                title: qsTr("Choose source account")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("Payee: %1").arg(page.payeeName)
                wrapMode: Text.Wrap
                color: Theme.highlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: (starlingClient.sourceAccounts || []).length === 0
                text: qsTr("No source accounts available yet.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: starlingClient.sourceAccounts

                delegate: BackgroundItem {
                    width: parent ? parent.width : page.width
                    height: accountCard.height + Theme.paddingMedium

                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("PaymentPage.qml"), {
                            payeeUid: page.payeeUid,
                            payeeName: page.payeeName,
                            accountData: page.accountData,
                            sourceAccountData: modelData
                        })
                    }

                    Rectangle {
                        id: accountCard
                        x: Theme.horizontalPageMargin
                        y: Theme.paddingSmall
                        width: page.width - 2 * x
                        height: accountColumn.height + 2 * Theme.paddingMedium
                        radius: Theme.paddingMedium
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                        border.width: 1
                        border.color: Theme.rgba(Theme.primaryColor, 0.15)

                        Column {
                            id: accountColumn
                            x: Theme.paddingMedium
                            y: Theme.paddingMedium
                            width: parent.width - 2 * Theme.paddingMedium
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: valueOrEmpty(modelData.accountName).length > 0
                                      ? valueOrEmpty(modelData.accountName)
                                      : qsTr("Account")
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeMedium
                                wrapMode: Text.Wrap
                            }

                            Label {
                                width: parent.width
                                visible: valueOrEmpty(modelData.accountNumber).length > 0
                                text: qsTr("Account number: %1").arg(valueOrEmpty(modelData.accountNumber))
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.Wrap
                            }

                            Label {
                                width: parent.width
                                visible: valueOrEmpty(modelData.sortCode).length > 0
                                text: qsTr("Sort code: %1").arg(valueOrEmpty(modelData.sortCode))
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.Wrap
                            }

                            Label {
                                width: parent.width
                                visible: modelData.isDefault === true
                                text: qsTr("Default account")
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
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
        z: 998
        onUnlockRequested: starlingClient.unlock()
    }

    ActivityCatcher {
        z: 997
        enabled: !starlingClient.locked
    }
}
