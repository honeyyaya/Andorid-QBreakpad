#include "qbreakpad_c_api.h"
#include "CrashHandler.h"

#include <QString>

bool qbreakpad_init(const char* dump_dir_utf8) {
    if (!dump_dir_utf8) {
        return false;
    }
    CrashHandler::instance().init(QString::fromUtf8(dump_dir_utf8));
    return true;
}

bool qbreakpad_write_minidump() {
    return CrashHandler::instance().writeMinidump();
}

