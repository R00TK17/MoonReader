// ============================================================
// CSV
// ============================================================

///|
/// 按行读取 CSV，返回「行 → 字段」的二维数组
pub fn read_csv_by_line(
  file_path : String,
  encoding? : Encoding? = None,
) -> Array[Array[String]] raise ReaderError {
  let content = read_txt(file_path, encoding~)
  let chars = content.iter().to_array()
  let n = chars.length()
  let records : Array[Array[String]] = []
  let mut record : Array[String] = []
  let mut field = ""
  let mut in_quotes = false
  let mut i = 0
  while i < n {
    let c = chars[i]
    if in_quotes {
      if c == '"' {
        if i + 1 < n && chars[i + 1] == '"' {
          field = field + "\""
          i = i + 1
        } else {
          in_quotes = false
        }
      } else {
        field = field + c.to_string()
      }
    } else if c == '"' {
      in_quotes = true
    } else if c == ',' {
      record.push(field)
      field = ""
    } else if c == '\n' {
      record.push(field)
      records.push(record)
      record = []
      field = ""
    } else if c == '\r' {
      // 忽略 CR，兼容 CRLF
    } else {
      field = field + c.to_string()
    }
    i = i + 1
  }
  // 最后一个字段 / 记录（若文件不以换行结尾）
  if field != "" || record.length() > 0 {
    record.push(field)
    records.push(record)
  }
  records
}

///|
/// 按列读取 CSV：返回「列 → 值」的二维数组（转置）
pub fn read_csv_by_column(
  file_path : String,
  encoding? : Encoding? = None,
) -> Array[Array[String]] raise ReaderError {
  let rows = read_csv_by_line(file_path, encoding~)
  if rows.length() == 0 {
    return []
  }
  let ncols = rows[0].length()
  let cols : Array[Array[String]] = []
  let mut i = 0
  while i < ncols {
    let col : Array[String] = []
    for row in rows {
      if i < row.length() {
        col.push(row[i])
      } else {
        col.push("")
      }
    }
    cols.push(col)
    i = i + 1
  }
  cols
}

///|
/// 按块读取 CSV：每 block_size 行一个块
pub fn read_csv_by_block(
  file_path : String,
  block_size : Int,
  encoding? : Encoding? = None,
) -> Array[Array[Array[String]]] raise ReaderError {
  let rows = read_csv_by_line(file_path, encoding~)
  let blocks : Array[Array[Array[String]]] = []
  let mut cur : Array[Array[String]] = []
  for row in rows {
    cur.push(row)
    if cur.length() == block_size {
      blocks.push(cur)
      cur = []
    }
  }
  if cur.length() > 0 {
    blocks.push(cur)
  }
  blocks
}
