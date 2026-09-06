// ============================================================
// ZIP
// 解压基于 hustcer/fzip（纯 MoonBit 的 DEFLATE/ZIP 实现）
// ============================================================

///|
/// ZIP 包内的一个条目：文件名 + 原始内容字节
pub(all) struct ZipEntry {
  name : String
  content : Bytes
}

///|
/// 把条目内容自动检测编码并解码为字符串（非法字节用 U+FFFD 替换）。
/// encoding 可显式指定解码方式。
pub fn ZipEntry::text(self : ZipEntry, encoding? : Encoding? = None) -> String {
  match encoding {
    Some(e) => decode(self.content, e)
    None => decode_auto(self.content)
  }
}

///|
/// 一次读盘并解压 zip 内所有条目（文件名 + 内容）。
/// 需要多个条目时用这个，避免反复读盘。
pub fn read_zip_entries(
  file_path : String,
) -> Array[ZipEntry] raise ReaderError {
  let data = read_txt_by_byte(file_path).to_fixedarray()
  let items = @fzip.unzip_sync(data) catch {
    FzipError(message~, ..) =>
      raise ReaderError::Parse("ZIP 解压失败: " + message)
  }
  let entries : Array[ZipEntry] = []
  for kv in items {
    let (name, content) = kv
    entries.push({
      name,
      content: Bytes::from_array(content.iter().to_array()),
    })
  }
  entries
}

///|
/// 列出 zip 包内所有文件名（只读中央目录，不解压内容）
pub fn list_zip_filenames(
  file_path : String,
) -> Array[String] raise ReaderError {
  let data = read_txt_by_byte(file_path).to_fixedarray()
  let infos = @fzip.unzip_list(data) catch {
    FzipError(message~, ..) =>
      raise ReaderError::Parse("ZIP 解析失败: " + message)
  }
  infos.map(fn(info) { info.name })
}

///|
/// 读取 zip 包内某个文件的内容，返回原始字节
pub fn read_zip_file(
  file_path : String,
  inner_name : String,
) -> Bytes raise ReaderError {
  let entries = read_zip_entries(file_path)
  for e in entries {
    if e.name == inner_name {
      return e.content
    }
  }
  raise ReaderError::Parse("zip 内未找到文件: " + inner_name)
}

///|
/// 读取 zip 包内某个文件的内容，自动检测编码并解码为字符串。
/// encoding 可显式指定解码方式。
pub fn read_zip_text(
  file_path : String,
  inner_name : String,
  encoding? : Encoding? = None,
) -> String raise ReaderError {
  let bytes = read_zip_file(file_path, inner_name)
  match encoding {
    Some(e) => decode(bytes, e)
    None => decode_auto(bytes)
  }
}
