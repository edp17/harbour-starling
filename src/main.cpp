#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <sailfishapp.h>

#include "starlingclient.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);
    QQuickView *view = SailfishApp::createView();

    StarlingClient client;
    view->rootContext()->setContextProperty("starlingClient", &client);

    view->setSource(SailfishApp::pathTo("qml/harbour-starling.qml"));
    view->show();

    return app->exec();
}
