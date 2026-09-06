// ============================================================
// MoonReader — MoonBit 文件内容读取库
//
// 用纯 MoonBit 实现常见文本/数据格式的读取接口：
//   TXT / CSV / JSON / JSONL / TAR
//
// 硬格式（PDF / Excel .xls / RAR 等）依赖底层解析器，后续阶段用 FFI 补齐。
// ============================================================

/// 统一的错误类型：IO 错误 / 解析错误
pub(all) suberror ReaderError {
  Io(String)
  Parse(String)
}
