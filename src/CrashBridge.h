#pragma once

#include <QObject>
#include <QDebug>
#include "CrashHandler.h"

class CrashBridge : public QObject {
    Q_OBJECT
public:
    explicit CrashBridge(QObject* parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE bool writeDump() {
        return CrashHandler::instance().writeMinidump();
    }

    Q_INVOKABLE void crashNow() {
        qWarning() << "Intentional crash for testing";
        volatile int* p = nullptr;
        *p = 1;
    }
};



