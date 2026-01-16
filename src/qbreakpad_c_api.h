#pragma once

#include "qbreakpad_export.h"

#ifdef __cplusplus
extern "C" {
#endif

// 初始化 Breakpad，dump_dir_utf8 为 UTF-8 编码的目录路径
QBREAKPAD_EXPORT bool qbreakpad_init(const char* dump_dir_utf8);

// 主动写一个 minidump，返回 true/false
QBREAKPAD_EXPORT bool qbreakpad_write_minidump();

#ifdef __cplusplus
}
#endif

