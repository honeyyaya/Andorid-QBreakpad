#pragma once

#include <QtCore/qglobal.h>

#if defined(QBREAKPAD_WRAPPER_LIBRARY)
#  define QBREAKPAD_EXPORT Q_DECL_EXPORT
#else
#  define QBREAKPAD_EXPORT Q_DECL_IMPORT
#endif

