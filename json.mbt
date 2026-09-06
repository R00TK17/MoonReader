// ============================================================
// JSON / JSONL
// ============================================================

///|
fn parse_json(s : String) -> Json raise ReaderError {
  @json.parse(s.view()) catch {
    e => raise ReaderError::Parse(e.to_string())
  }
}

///|
/// 解析 JSON 文件为动态值（Json）
pub fn read_json(
  file_path : String,
  encoding? : Encoding? = None,
) -> Json raise ReaderError {
  parse_json(read_txt(file_path, encoding~))
}

///|
/// 按块读取 JSON：假设顶层是数组，每 block_size 个元素一个块
pub fn read_json_by_block(
  file_path : String,
  block_size : Int,
  encoding? : Encoding? = None,
) -> Array[Array[Json]] raise ReaderError {
  let root = read_json(file_path, encoding~)
  let arr = match root {
    Array(a) => a
    _ => raise ReaderError::Parse("JSON 顶层不是数组")
  }
  let blocks : Array[Array[Json]] = []
  let mut cur : Array[Json] = []
  for v in arr {
    cur.push(v)
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

///|
/// 按行读取 JSONL（每行一个 JSON 对象）
pub fn read_jsonl_by_line(
  file_path : String,
  encoding? : Encoding? = None,
) -> Array[Json] raise ReaderError {
  let content = read_txt(file_path, encoding~)
  let result : Array[Json] = []
  for v in content.split("\n".view()) {
    let line = v.trim_end(chars="\r".view()).to_owned()
    if line != "" {
      result.push(parse_json(line))
    }
  }
  result
}
