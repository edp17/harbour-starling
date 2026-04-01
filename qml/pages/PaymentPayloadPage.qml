import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: page
    allowedOrientations: Orientation.All

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
                title: qsTr("Payment payload")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("This is the preview payload only. No payment will be sent.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
            }

            TextArea {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: starlingClient.paymentPreviewJson
                readOnly: true
                wrapMode: TextEdit.NoWrap
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
