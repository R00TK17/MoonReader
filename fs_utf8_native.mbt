// ============================================================
// UTF-8 路径感知的文件读取
// 解决 Windows 下 @fs.read_file_to_bytes 无法打开中文路径的问题
// ============================================================

///|
/// 不透明指针，表示 C 侧返回的文件内容（或空指针）
#external
priv type Handler

///|
/// 用 UTF-8 路径打开并读取整个文件（见 fs_utf8.c）
#borrow(path)
extern "C" fn read_file_utf8_ffi(path : Bytes) -> Handler = "moonreader_read_file_utf8"

///|
/// 判断 C 指针是否为空
extern "C" fn is_null(ptr : Handler) -> Int = "moonreader_is_null"

///|
/// 用 UTF-8 路径把字节写入文件（覆盖写），返回 0 成功 / 非 0 失败
#borrow(path, data)
extern "C" fn write_file_utf8_ffi(path : Bytes, data : Bytes) -> Int = "moonreader_write_file_utf8"

///|
/// Handler 转 Bytes（两者底层都是字节数组指针）
fn handler_to_bytes(h : Handler) -> Bytes = "%identity"

///|
/// 以 UTF-8 路径读取文件为字节序列（支持中文文件名）
pub fn read_file_to_bytes_utf8(path : String) -> Bytes raise ReaderError {
  // String 是 UTF-16LE 内部表示，转成 UTF-8 字节后交给 C 侧
  let path_bytes = @utf8.encode(path.to_string_view())
  let h = read_file_utf8_ffi(path_bytes)
  if is_null(h) != 0 {
    raise ReaderError::Io("读取文件失败: " + path)
  }
  handler_to_bytes(h)
}

///|
/// 以 UTF-8 路径把字节写入文件（覆盖写，支持中文文件名）
pub fn write_file_to_bytes_utf8(
  path : String,
  data : Bytes,
) -> Unit raise ReaderError {
  let path_bytes = @utf8.encode(path.to_string_view())
  let r = write_file_utf8_ffi(path_bytes, data)
  if r != 0 {
    raise ReaderError::Io("写入文件失败: " + path)
  }
}
