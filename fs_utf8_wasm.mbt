// ============================================================
// MoonReader — wasm-gc（浏览器 / IDE 预览）目标的文件读写
//
// 委托给 moonbitlang/x/fs：底层走 moonrun 的 __moonbit_fs_unstable
// （read_file_to_bytes_new / get_file_content 等），路径以 String 交给宿主，
// 中文文件名天然支持（宿主侧 UTF-8 / JS 字符串处理）。
// 仅在 wasm-gc 目标编译；native 见 fs_utf8_native.mbt。
// ============================================================

///|
/// 以路径读取文件为字节序列（wasm-gc 委托 @fs，支持中文文件名）
fn read_file_to_bytes_utf8(path : String) -> Bytes raise ReaderError {
  @fs.read_file_to_bytes(path) catch {
    _ => raise ReaderError::Io("读取文件失败: " + path)
  }
}

///|
/// 以路径把字节写入文件（覆盖写，wasm-gc 委托 @fs）
fn write_file_to_bytes_utf8(
  path : String,
  data : Bytes,
) -> Unit raise ReaderError {
  @fs.write_bytes_to_file(path, data) catch {
    _ => raise ReaderError::Io("写入文件失败: " + path)
  }
}
