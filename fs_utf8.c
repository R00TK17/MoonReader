// ============================================================
// MoonReader — UTF-8 路径感知的文件读取（native stub）
//
// 背景：@fs 的 fopen_ffi 在 Windows 上直接用 fopen((const char*)path, ...)，
//       Windows 的 fopen 走 ANSI 代码页，遇到中文路径会打不开。
//       这里改用 MultiByteToWideChar(CP_UTF8, ...) + _wfopen，正确支持中文路径。
// ============================================================

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <wchar.h>
#include <windows.h>
#endif

#include "moonbit.h"

// 打开一个以 UTF-8 编码的文件路径，读取其全部内容。
// path : UTF-8 字节序列（由 MoonBit 侧 @utf8.encode 生成）
// 返回 : 文件内容 moonbit_bytes_t；失败返回 NULL
MOONBIT_FFI_EXPORT moonbit_bytes_t moonreader_read_file_utf8(moonbit_bytes_t path) {
  int32_t len = Moonbit_array_length(path);

  // 复制出带 NUL 结尾的 C 字符串（UTF-8 字节）
  char *cpath = (char *)malloc((size_t)len + 1);
  if (cpath == NULL) {
    return NULL;
  }
  memcpy(cpath, path, (size_t)len);
  cpath[len] = '\0';

  FILE *f = NULL;
#ifdef _WIN32
  // 先算宽字符长度，再转换，最后用 _wfopen 打开
  int wlen = MultiByteToWideChar(CP_UTF8, 0, cpath, -1, NULL, 0);
  if (wlen > 0) {
    wchar_t *wpath = (wchar_t *)malloc((size_t)wlen * sizeof(wchar_t));
    if (wpath != NULL) {
      MultiByteToWideChar(CP_UTF8, 0, cpath, -1, wpath, wlen);
      f = _wfopen(wpath, L"rb");
      free(wpath);
    }
  }
#else
  f = fopen(cpath, "rb");
#endif
  free(cpath);
  if (f == NULL) {
    return NULL;
  }

  // 读取整个文件
  if (fseek(f, 0, SEEK_END) != 0) {
    fclose(f);
    return NULL;
  }
  long sz = ftell(f);
  if (sz < 0) {
    fclose(f);
    return NULL;
  }
  if (fseek(f, 0, SEEK_SET) != 0) {
    fclose(f);
    return NULL;
  }

  moonbit_bytes_t out = moonbit_make_bytes((int32_t)sz, 0);
  if (sz > 0) {
    size_t got = fread(out, 1, (size_t)sz, f);
    (void)got;
  }
  fclose(f);
  return out;
}

// 判断指针是否为空（供 MoonBit 侧检测打开失败）
MOONBIT_FFI_EXPORT int moonreader_is_null(void *ptr) {
  return ptr == NULL;
}

// 以 UTF-8 编码的文件路径打开文件并写入全部内容（覆盖写）。
// path : UTF-8 字节序列；data : 要写入的字节序列
// 返回 : 0 表示成功，非 0 表示失败
MOONBIT_FFI_EXPORT int moonreader_write_file_utf8(moonbit_bytes_t path,
                                                  moonbit_bytes_t data) {
  int32_t plen = Moonbit_array_length(path);
  int32_t dlen = Moonbit_array_length(data);

  char *cpath = (char *)malloc((size_t)plen + 1);
  if (cpath == NULL) {
    return 1;
  }
  memcpy(cpath, path, (size_t)plen);
  cpath[plen] = '\0';

  FILE *f = NULL;
#ifdef _WIN32
  int wlen = MultiByteToWideChar(CP_UTF8, 0, cpath, -1, NULL, 0);
  if (wlen > 0) {
    wchar_t *wpath = (wchar_t *)malloc((size_t)wlen * sizeof(wchar_t));
    if (wpath != NULL) {
      MultiByteToWideChar(CP_UTF8, 0, cpath, -1, wpath, wlen);
      f = _wfopen(wpath, L"wb");
      free(wpath);
    }
  }
#else
  f = fopen(cpath, "wb");
#endif
  free(cpath);
  if (f == NULL) {
    return 1;
  }

  if (dlen > 0) {
    size_t wrote = fwrite(data, 1, (size_t)dlen, f);
    (void)wrote;
  }
  fclose(f);
  return 0;
}
