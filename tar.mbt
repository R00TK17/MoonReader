// ============================================================
// TAR
// ============================================================

///|
/// 从字节数组读取以 NUL 结尾的字符串字段（tar 头），按 UTF-8 解码（支持中文文件名）
fn tar_field_cstr(arr : Array[Byte], start : Int, len : Int) -> String {
  let mut end = start
  while end < start + len && end < arr.length() && arr[end].to_int() != 0 {
    end = end + 1
  }
  @utf8.decode_lossy(Bytes::from_array(arr.view(start~, end~)))
}

///|
/// 从字节数组直接解析八进制字段（tar 头 size/mode 等）
fn tar_octal_field(arr : Array[Byte], start : Int, len : Int) -> Int {
  let mut v = 0
  let mut i = start
  while i < start + len && i < arr.length() && arr[i].to_int() != 0 {
    let b = arr[i].to_int()
    if b >= 0x30 && b <= 0x37 {
      v = v * 8 + (b - 0x30)
    }
    i = i + 1
  }
  v
}

///|
/// tar 包内的一个条目：文件名 + 原始内容字节
pub(all) struct TarEntry {
  name : String
  content : Bytes
}

///|
/// 把条目内容自动检测编码并解码为字符串（非法字节用 U+FFFD 替换）。
/// encoding 可显式指定解码方式。
pub fn TarEntry::text(
  self : TarEntry,
  encoding? : Option[Encoding] = None,
) -> String {
  match encoding {
    Some(e) => decode(self.content, e)
    None => decode_auto(self.content)
  }
}

///|
/// 把整个 tar 字节流解析为条目数组（一次遍历，每个条目内容独立拷贝）
fn parse_tar(data : Bytes) -> Array[TarEntry] {
  let arr = data.to_array()
  let n = arr.length()
  let entries : Array[TarEntry] = []
  let mut offset = 0
  while offset + 512 <= n {
    let name = tar_field_cstr(arr, offset, 100)
    let size = tar_octal_field(arr, offset + 124, 12)
    if size == 0 && name == "" {
      break
    }
    if name != "" {
      let data_start = offset + 512
      let data_end = if data_start + size <= n { data_start + size } else { n }
      entries.push({
        name,
        content: Bytes::from_array(arr.view(start=data_start, end=data_end)),
      })
    }
    let data_blocks = (size + 511) / 512
    offset = offset + 512 + data_blocks * 512
  }
  entries
}

///|
/// 一次读盘并解析 tar 内所有条目（文件名 + 内容）。
/// 需要多个条目时用这个，避免反复读盘。
pub fn read_tar_entries(
  file_path : String,
) -> Array[TarEntry] raise ReaderError {
  parse_tar(read_txt_by_byte(file_path))
}

///|
/// 列出 tar 包内所有文件名
pub fn list_tar_filenames(
  file_path : String,
) -> Array[String] raise ReaderError {
  parse_tar(read_txt_by_byte(file_path)).map(fn(e) { e.name })
}

///|
/// 读取 tar 包内某个文件的内容，返回原始字节
pub fn read_tar_file(
  file_path : String,
  inner_name : String,
) -> Bytes raise ReaderError {
  let entries = parse_tar(read_txt_by_byte(file_path))
  for e in entries {
    if e.name == inner_name {
      return e.content
    }
  }
  raise ReaderError::Parse("tar 内未找到文件: " + inner_name)
}

///|
/// 读取 tar 包内某个文件的内容，自动检测编码并解码为字符串。
/// encoding 可显式指定解码方式。
pub fn read_tar_text(
  file_path : String,
  inner_name : String,
  encoding? : Option[Encoding] = None,
) -> String raise ReaderError {
  let bytes = read_tar_file(file_path, inner_name)
  match encoding {
    Some(e) => decode(bytes, e)
    None => decode_auto(bytes)
  }
}
