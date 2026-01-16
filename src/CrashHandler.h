#pragma once

#include <QString>
#include "qbreakpad_export.h"

class QBREAKPAD_EXPORT CrashHandler {
public:
    static CrashHandler& instance();

    void init(const QString& dumpDir);
    bool writeMinidump();

private:
    CrashHandler() = default;
};



