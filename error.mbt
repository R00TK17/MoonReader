// ============================================================
// MoonReader — MoonBit 文件内容读取库
//
// 用纯 MoonBit 实现 12 种文件格式的读取接口：
//   TXT / CSV / JSON / JSONL / XML / Markdown / ZIP / TAR / DOCX / XLSX / PPTX / PDF
//
// 文本类格式自动检测编码（UTF-8 / UTF-16 / UTF-32 / GBK / Big5 / Latin-1），
// Windows 下中文文件名友好（_wfopen + UTF-8 路径）。
// ============================================================

///|
/// 统一的错误类型：IO 错误 / 解析错误
pub(all) suberror ReaderError {
  Io(String)
  Parse(String)
}
