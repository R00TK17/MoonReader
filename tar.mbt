// ============================================================
// TAR
// ============================================================

/// 从字节数组读取以 NUL 结尾的字符串字段（tar 头），按 Latin-1/ASCII 逐字节解码
fn tar_field_cstr(arr : Array[Byte], start : Int, len : Int) -> String {
  let mut s = ""
  let mut i = start
  while i < start + len && i < arr.length() && arr[i].to_int() != 0 {
    s = s + arr[i].to_char().to_string()
    i = i + 1
  }
  s
}

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

/// 列出 tar 包内所有文件名
pub fn list_tar_filenames(file_path : String) -> Array[String] raise ReaderError {
  let data = read_txt_by_byte(file_path)
  let arr = data.to_array()
  let n = arr.length()
  let names : Array[String] = []
  let mut offset = 0
  while offset + 512 <= n {
    let name = tar_field_cstr(arr, offset, 100)
    let size = tar_octal_field(arr, offset + 124, 12)
    if size == 0 && name == "" {
      break
    }
    if name != "" {
      names.push(name)
    }
    let data_blocks = (size + 511) / 512
    offset = offset + 512 + data_blocks * 512
  }
  names
}

/// 读取 tar 包内某个文件的内容，返回原始字节
pub fn read_tar_file(file_path : String, inner_name : String) -> Bytes raise ReaderError {
  let data = read_txt_by_byte(file_path)
  let arr = data.to_array()
  let n = arr.length()
  let mut offset = 0
  while offset + 512 <= n {
    let name = tar_field_cstr(arr, offset, 100)
    let size = tar_octal_field(arr, offset + 124, 12)
    if size == 0 && name == "" {
      break
    }
    if name == inner_name {
      let data_start = offset + 512
      let data_end = if data_start + size <= n { data_start + size } else { n }
      return Bytes::from_array(arr.view(start=data_start, end=data_end))
    }
    let data_blocks = (size + 511) / 512
    offset = offset + 512 + data_blocks * 512
  }
  raise ReaderError::Parse("tar 内未找到文件: " + inner_name)
}

/// 读取 tar 包内某个文件的内容，按 UTF-8 解码为字符串（非法字节用 U+FFFD 替换）
pub fn read_tar_text(file_path : String, inner_name : String) -> String raise ReaderError {
  @utf8.decode_lossy(read_tar_file(file_path, inner_name))
}
