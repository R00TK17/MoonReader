// ============================================================
// TXT
// ============================================================

///|
/// 读取整个文本文件为字符串（UTF-8 路径感知，支持中文文件名）。
/// encoding 缺省自动检测（BOM / UTF-8 / UTF-16 / GBK / Big5 / Latin-1）；
/// 显式指定则按指定编码解码。
pub fn read_txt(
  file_path : String,
  encoding? : Encoding? = None,
) -> String raise ReaderError {
  let bytes = read_file_to_bytes_utf8(file_path)
  match encoding {
    Some(e) => decode(bytes, e)
    None => decode_auto(bytes)
  }
}

///|
/// 按行读取文本文件，返回字符串数组（已去除行尾 \n / \r\n）。
/// encoding 缺省自动检测，可显式指定。
pub fn read_txt_by_line(
  file_path : String,
  encoding? : Encoding? = None,
) -> Array[String] raise ReaderError {
  let content = read_txt(file_path, encoding~)
  let lines : Array[String] = []
  for v in content.split("\n".view()) {
    lines.push(v.trim_end(chars="\r".view()).to_owned())
  }
  // 文件以换行结尾时，去掉末尾产生的空字符串
  if lines.length() > 0 && lines[lines.length() - 1] == "" {
    let _ = lines.pop()
  }
  lines
}

///|
/// 以路径读取文件为原始字节（支持中文文件名）。
/// 内部按目标自动选择 native C stub 或 wasm-gc 的 @fs，公开面一致。
pub fn read_file_to_bytes(path : String) -> Bytes raise ReaderError {
  read_file_to_bytes_utf8(path)
}

///|
/// 以路径把字节写入文件（覆盖写，支持中文文件名）
pub fn write_file_to_bytes(
  path : String,
  data : Bytes,
) -> Unit raise ReaderError {
  write_file_to_bytes_utf8(path, data)
}

///|
/// 读取文本文件为字节序列（等价 read_file_to_bytes，属 TXT 系列命名）
pub fn read_txt_by_byte(file_path : String) -> Bytes raise ReaderError {
  read_file_to_bytes(file_path)
}

///|
/// 按块读取文本文件：每块 block_size 个字符（注意是字符数，非字节数），转成字符串。
/// encoding 缺省自动检测，可显式指定。
pub fn read_txt_by_block(
  file_path : String,
  block_size : Int,
  encoding? : Encoding? = None,
) -> Array[String] raise ReaderError {
  let content = read_txt(file_path, encoding~)
  let n = content.length()
  let blocks : Array[String] = []
  let mut i = 0
  while i < n {
    let end = if i + block_size < n { i + block_size } else { n }
    blocks.push(content[i:end].to_owned())
    i = end
  }
  blocks
}
