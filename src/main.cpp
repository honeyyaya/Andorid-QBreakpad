#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>

#include "CrashHandler.h"
#include "CrashBridge.h"
int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    QString dumpDir = QStandardPaths::writableLocation(
                          QStandardPaths::AppDataLocation)
                      + "/dumps";
    CrashHandler::instance().init(dumpDir);

    QQmlApplicationEngine engine;
    CrashBridge bridge;
    engine.rootContext()->setContextProperty("CrashBridge", &bridge);

    const QUrl url(QStringLiteral("qrc:/Main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl) {
                QCoreApplication::exit(-1);
            }
        },
        Qt::QueuedConnection);

    engine.load(url);
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}


