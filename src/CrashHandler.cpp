#include "CrashHandler.h"

#include <QDir>
#include <QStandardPaths>
#include <QDebug>
#include <memory>

#ifdef HAVE_BREAKPAD
#include <client/linux/handler/exception_handler.h>
#include <client/linux/handler/minidump_descriptor.h>
static std::shared_ptr<google_breakpad::ExceptionHandler> g_handler;
#endif

CrashHandler& CrashHandler::instance() {
    static CrashHandler inst;
    return inst;
}

void CrashHandler::init(const QString& dumpDir) {
    QDir().mkpath(dumpDir);

#ifdef HAVE_BREAKPAD
    google_breakpad::MinidumpDescriptor desc(dumpDir.toStdString());
    desc.UpdatePath();
    g_handler = std::make_shared<google_breakpad::ExceptionHandler>(
        desc,
        /*filter*/ nullptr,
        /*callback*/ [](const google_breakpad::MinidumpDescriptor& md,
                        void*, bool succeeded) {
            qDebug() << "Minidump written to" << QString::fromStdString(md.path());
            return succeeded;
        },
        /*callback-context*/ nullptr,
        true,  // install_handler
        -1
    );
#else
    qWarning() << "Breakpad not linked; init skipped";
#endif
}

bool CrashHandler::writeMinidump() {
#ifdef HAVE_BREAKPAD
    if (g_handler) {
        return g_handler->WriteMinidump();
    }
    return false;
#else
    qWarning() << "Breakpad not linked; writeMinidump noop";
    return false;
#endif
}



