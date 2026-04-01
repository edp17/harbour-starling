import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Token security")
            }

            SectionHeader {
                text: qsTr("Personal Access Token")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                text: qsTr("The Personal Access Token is used to access your Starling account data from this app.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("It is stored locally on your device so that you do not need to enter it every time you open the app.")
            }

            SectionHeader {
                text: qsTr("Payee write token")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                text: qsTr("The payee write token is used only for actions that create or modify payees.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("It is stored separately from the main Personal Access Token because it grants additional permissions.")
            }

            SectionHeader {
                text: qsTr("App lock")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                text: qsTr("When the app locks, sensitive account data is hidden until you unlock the app again.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("You can configure whether the app locks immediately when sent to the background, or only after the selected inactivity timeout.")
            }

            SectionHeader {
                text: qsTr("App PIN")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                text: qsTr("If enabled, the app PIN is required before the app can be unlocked.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("The PIN helps protect your session on the device, but it does not replace good device security.")
            }

            SectionHeader {
                text: qsTr("Important")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                text: qsTr("Anyone with access to your unlocked device or active app session may be able to access your account information.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                text: qsTr("If you believe a token has been exposed, revoke it in your Starling developer settings and replace it in this app.")
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }
        }
    }
}
