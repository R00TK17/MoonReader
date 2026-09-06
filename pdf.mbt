// ============================================================
// PDF
//
// 纯 MoonBit 的 PDF 文本提取：
//   1. 扫描文件，解析间接对象（字典 / 数组 / 字符串 / 名称 / 数字 / 引用）
//   2. 遍历页树（Catalog → Pages → Kids），逐页取内容流
//   3. FlateDecode 解压交给 hustcer/fzip（unzlib_sync / inflate_sync）
//   4. 解析内容流文本算子（Tj / TJ / ' / "），按当前字体解码
//   5. 字体编码：CID 字体（Type0/Identity-H）走 ToUnicode CMap，
//      简单字体（TrueType/WinAnsi 等）按 Latin-1 直接映射
//
// 已知限制：仅实现 bfchar + 简单 bfrange 的 ToUnicode；不解析内联图片、
// 页面继承的 Resources（仅取页自身 /Resources）。
// ============================================================

///|
/// 读取 PDF 全部文本（各页按换行拼接）
pub fn read_pdf_text(path : String) -> String raise ReaderError {
  read_pdf_text_by_page(path).join("\n")
}

///|
/// 读取 PDF 每页文本（一页一个字符串，页内文本片段按换行拼接）
pub fn read_pdf_text_by_page(path : String) -> Array[String] raise ReaderError {
  let data = read_txt_by_byte(path).to_array()
  let doc = parse_pdf(data)
  let root_num = get_root(doc)
  let root_dict = match lookup(doc, root_num).value {
    PDict(kv) => kv
    _ => raise ReaderError::Parse("PDF Catalog 无效")
  }
  let pages_num = match dict_get(root_dict, "Pages") {
    Some(PRef(n, _)) => n
    _ => raise ReaderError::Parse("PDF 缺少 Pages")
  }
  let pages = collect_pages(doc, pages_num)
  let out : Array[String] = []
  for pnum in pages {
    let pobj = lookup(doc, pnum)
    let pdict = match pobj.value {
      PDict(kv) => kv
      _ => []
    }
    let fonts = build_page_fonts(doc, pdict)
    let content = get_content_bytes(doc, pdict)
    let runs = extract_text(content, fonts)
    out.push(runs.join("\n"))
  }
  out
}

// ============================================================
// 数据模型
// ============================================================

///|
/// PDF 值：动态类型
priv enum PdfValue {
  PNull
  PBool(Bool)
  PNum
  PStr(Bytes)
  PName(String)
  PArr(Array[PdfValue])
  PDict(Array[(String, PdfValue)])
  PRef(Int, Int)
}

///|
/// 一个间接对象：值 + 可选的流字节
priv struct PdfObject {
  value : PdfValue
  stream : Bytes?
}

///|
/// 整个文档：对象表（按对象号线性查找，文件很小足够）
priv struct PdfDoc {
  objects : Array[(Int, PdfObject)]
}

///|
/// 字体描述：simple = 单字节编码；否则按 2 字节 CID 查 cid_map
priv struct PdfFont {
  simple : Bool
  cid_map : Array[(Int, Int)]
}

// ============================================================
// 文档解析：扫描对象
// ============================================================

///|
/// 扫描整个文件，按 "N G obj ... endobj" 找出所有间接对象
fn parse_pdf(data : Array[Byte]) -> PdfDoc raise ReaderError {
  let n = data.length()
  let objs : Array[(Int, PdfObject)] = []
  let mut i = 0
  while i < n {
    if !is_digit(data[i]) {
      i = i + 1
      continue
    }
    match try_obj_header(data, n, i) {
      Some((num, _gen, after)) => {
        let pos = @ref.new(after)
        let value = parse_value(data, n, pos)
        pdf_skip_ws(data, n, pos)
        let mut stream : Bytes? = None
        if matches_word(data, n, pos, "stream") {
          pos.val = pos.val + 6
          if pos.val < n && data[pos.val] == b'\r' {
            pos.val = pos.val + 1
          }
          if pos.val < n && data[pos.val] == b'\n' {
            pos.val = pos.val + 1
          }
          let start = pos.val
          let e = find_endstream(data, start, n)
          if e < 0 {
            raise ReaderError::Parse("PDF 流缺少 endstream")
          }
          let rawb = slice_bytes(data, start, e)
          let mut e2 = rawb.length()
          while e2 > 0 && (rawb[e2 - 1] == b'\r' || rawb[e2 - 1] == b'\n') {
            e2 = e2 - 1
          }
          stream = Some(Bytes::from_array(slice_bytes(rawb, 0, e2)))
          pos.val = e + 9
        }
        objs.push((num, { value, stream }))
        i = pos.val
      }
      None => i = i + 1
    }
  }
  { objects: objs }
}

///|
/// 尝试在 i 处解析 "N G obj" 头部，成功返回 (对象号, 代, 头部之后的位置)
fn try_obj_header(
  data : Array[Byte],
  n : Int,
  i : Int,
) -> (Int, Int, Int)? {
  let mut p = i
  let mut num = 0
  while p < n && is_digit(data[p]) {
    num = num * 10 + (data[p].to_int() - 48)
    p = p + 1
  }
  if p >= n || !is_ws_byte(data[p]) {
    return None
  }
  while p < n && is_ws_byte(data[p]) {
    p = p + 1
  }
  let mut gen = 0
  while p < n && is_digit(data[p]) {
    gen = gen * 10 + (data[p].to_int() - 48)
    p = p + 1
  }
  if p >= n || !is_ws_byte(data[p]) {
    return None
  }
  while p < n && is_ws_byte(data[p]) {
    p = p + 1
  }
  if p + 3 > n {
    return None
  }
  if data[p] == b'o' && data[p + 1] == b'b' && data[p + 2] == b'j' {
    Some((num, gen, p + 3))
  } else {
    None
  }
}

///|
/// 在 data[start..] 中查找 "endstream"，返回其起始下标（未找到返回 -1）
fn find_endstream(data : Array[Byte], start : Int, n : Int) -> Int {
  let mut i = start
  while i + 8 < n {
    if data[i] == b'e' &&
      data[i + 1] == b'n' &&
      data[i + 2] == b'd' &&
      data[i + 3] == b's' &&
      data[i + 4] == b't' &&
      data[i + 5] == b'r' &&
      data[i + 6] == b'e' &&
      data[i + 7] == b'a' &&
      data[i + 8] == b'm' {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// 复制字节区间 [start, end) 为新的 Array[Byte]
fn slice_bytes(data : Array[Byte], start : Int, end : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut i = start
  while i < end && i < data.length() {
    out.push(data[i])
    i = i + 1
  }
  out
}

// ============================================================
// 值解析（递归下降）
// ============================================================

///|
fn parse_value(
  data : Array[Byte],
  n : Int,
  pos : Ref[Int],
) -> PdfValue raise ReaderError {
  pdf_skip_ws(data, n, pos)
  if pos.val >= n {
    raise ReaderError::Parse("PDF 解析意外结束")
  }
  let c = data[pos.val]
  if c == b'<' {
    if pos.val + 1 < n && data[pos.val + 1] == b'<' {
      parse_dict(data, n, pos)
    } else {
      parse_hex_string(data, n, pos)
    }
  } else if c == b'(' {
    parse_lit_string(data, n, pos)
  } else if c == b'[' {
    parse_array(data, n, pos)
  } else if c == b'/' {
    parse_name_value(data, n, pos)
  } else if c == b't' && matches_word(data, n, pos, "true") {
    pos.val = pos.val + 4
    PBool(true)
  } else if c == b'f' && matches_word(data, n, pos, "false") {
    pos.val = pos.val + 5
    PBool(false)
  } else if c == b'n' && matches_word(data, n, pos, "null") {
    pos.val = pos.val + 4
    PNull
  } else if c == b'-' || c == b'+' || c == b'.' || is_digit(c) {
    parse_number_or_ref(data, n, pos)
  } else {
    parse_bare_name(data, n, pos)
  }
}

///|
/// 解析字典 << ... >>
fn parse_dict(
  data : Array[Byte],
  n : Int,
  pos : Ref[Int],
) -> PdfValue raise ReaderError {
  pos.val = pos.val + 2
  let kv : Array[(String, PdfValue)] = []
  pdf_skip_ws(data, n, pos)
  while pos.val < n {
    if data[pos.val] == b'>' &&
      pos.val + 1 < n &&
      data[pos.val + 1] == b'>' {
      pos.val = pos.val + 2
      return PDict(kv)
    }
    if data[pos.val] != b'/' {
      pos.val = pos.val + 1
      continue
    }
    let key = parse_name_string(data, n, pos)
    let value = parse_value(data, n, pos)
    kv.push((key, value))
    pdf_skip_ws(data, n, pos)
  }
  PDict(kv)
}

///|
/// 解析数组 [ ... ]
fn parse_array(
  data : Array[Byte],
  n : Int,
  pos : Ref[Int],
) -> PdfValue raise ReaderError {
  pos.val = pos.val + 1
  let arr : Array[PdfValue] = []
  pdf_skip_ws(data, n, pos)
  while pos.val < n && data[pos.val] != b']' {
    arr.push(parse_value(data, n, pos))
    pdf_skip_ws(data, n, pos)
  }
  if pos.val < n && data[pos.val] == b']' {
    pos.val = pos.val + 1
  }
  PArr(arr)
}

///|
/// 解析十六进制字符串 <...>（保留原始字节）
fn parse_hex_string(data : Array[Byte], n : Int, pos : Ref[Int]) -> PdfValue {
  pos.val = pos.val + 1
  let buf : Array[Byte] = []
  let mut hi = -1
  while pos.val < n {
    let c = data[pos.val]
    if c == b'>' {
      pos.val = pos.val + 1
      break
    }
    if is_ws_byte(c) {
      pos.val = pos.val + 1
      continue
    }
    let v = hex_val(c)
    if v < 0 {
      pos.val = pos.val + 1
      continue
    }
    if hi < 0 {
      hi = v
    } else {
      buf.push((hi * 16 + v).to_byte())
      hi = -1
    }
    pos.val = pos.val + 1
  }
  if hi >= 0 {
    buf.push((hi * 16).to_byte())
  }
  PStr(Bytes::from_array(buf))
}

///|
/// 解析字面字符串 (...)，处理反斜杠转义与括号嵌套
fn parse_lit_string(data : Array[Byte], n : Int, pos : Ref[Int]) -> PdfValue {
  pos.val = pos.val + 1
  let buf : Array[Byte] = []
  let mut depth = 1
  while pos.val < n && depth > 0 {
    let c = data[pos.val]
    if c == b'\\' {
      pos.val = pos.val + 1
      if pos.val >= n {
        break
      }
      let e = data[pos.val]
      let ei = e.to_int()
      if ei == 'n'.to_int() {
        buf.push(b'\n')
        pos.val = pos.val + 1
      } else if ei == 'r'.to_int() {
        buf.push(b'\r')
        pos.val = pos.val + 1
      } else if ei == 't'.to_int() {
        buf.push(b'\t')
        pos.val = pos.val + 1
      } else if ei == 'b'.to_int() {
        buf.push(b'\x08')
        pos.val = pos.val + 1
      } else if ei == 'f'.to_int() {
        buf.push(b'\x0c')
        pos.val = pos.val + 1
      } else if ei == '('.to_int() {
        buf.push(b'(')
        pos.val = pos.val + 1
      } else if ei == ')'.to_int() {
        buf.push(b')')
        pos.val = pos.val + 1
      } else if ei == '\\'.to_int() {
        buf.push(b'\\')
        pos.val = pos.val + 1
      } else if ei == '\n'.to_int() {
        pos.val = pos.val + 1
      } else if ei == '\r'.to_int() {
        pos.val = pos.val + 1
        if pos.val < n && data[pos.val] == b'\n' {
          pos.val = pos.val + 1
        }
      } else if ei >= '0'.to_int() && ei <= '7'.to_int() {
        let mut v = ei - '0'.to_int()
        let mut cnt = 1
        pos.val = pos.val + 1
        while cnt < 3 &&
          pos.val < n &&
          data[pos.val].to_int() >= '0'.to_int() &&
          data[pos.val].to_int() <= '7'.to_int() {
          v = v * 8 + (data[pos.val].to_int() - '0'.to_int())
          pos.val = pos.val + 1
          cnt = cnt + 1
        }
        buf.push(v.to_byte())
      } else {
        buf.push(e)
        pos.val = pos.val + 1
      }
    } else if c == b'(' {
      depth = depth + 1
      buf.push(c)
      pos.val = pos.val + 1
    } else if c == b')' {
      depth = depth - 1
      if depth > 0 {
        buf.push(c)
      }
      pos.val = pos.val + 1
    } else {
      buf.push(c)
      pos.val = pos.val + 1
    }
  }
  PStr(Bytes::from_array(buf))
}

///|
/// 读取名称（从 '/' 开始），返回 String（含 #xx 转义处理）
fn parse_name_string(data : Array[Byte], n : Int, pos : Ref[Int]) -> String {
  let buf = read_name_bytes(data, n, pos)
  @utf8.decode_lossy(Bytes::from_array(buf))
}

///|
fn parse_name_value(data : Array[Byte], n : Int, pos : Ref[Int]) -> PdfValue {
  let buf = read_name_bytes(data, n, pos)
  PName(@utf8.decode_lossy(Bytes::from_array(buf)))
}

///|
fn read_name_bytes(data : Array[Byte], n : Int, pos : Ref[Int]) -> Array[Byte] {
  pos.val = pos.val + 1
  let buf : Array[Byte] = []
  while pos.val < n && !is_delim(data[pos.val]) {
    let c = data[pos.val]
    if c == b'#' && pos.val + 2 < n {
      let h = hex_val(data[pos.val + 1]) * 16 + hex_val(data[pos.val + 2])
      if h >= 0 {
        buf.push(h.to_byte())
        pos.val = pos.val + 3
      } else {
        buf.push(c)
        pos.val = pos.val + 1
      }
    } else {
      buf.push(c)
      pos.val = pos.val + 1
    }
  }
  buf
}

///|
/// 内容流中的操作符是无斜杠的裸名称，此处按名称读取
fn parse_bare_name(data : Array[Byte], n : Int, pos : Ref[Int]) -> PdfValue {
  let buf : Array[Byte] = []
  while pos.val < n && !is_delim(data[pos.val]) {
    buf.push(data[pos.val])
    pos.val = pos.val + 1
  }
  PName(@utf8.decode_lossy(Bytes::from_array(buf)))
}

///|
/// 数字或引用（N G R）：先尝试按引用解析，失败则按单个数字回退
fn parse_number_or_ref(data : Array[Byte], n : Int, pos : Ref[Int]) -> PdfValue {
  let save = pos.val
  match try_parse_int(data, n, pos) {
    Some(a) => {
      pdf_skip_ws(data, n, pos)
      match try_parse_int(data, n, pos) {
        Some(b) => {
          pdf_skip_ws(data, n, pos)
          if pos.val < n && data[pos.val] == b'R' {
            pos.val = pos.val + 1
            return PRef(a, b)
          }
        }
        None => ()
      }
    }
    None => ()
  }
  pos.val = save
  parse_number_token(data, n, pos)
  PNum
}

///|
/// 尝试在 pos 处解析整数，成功则前进并返回 Some，否则位置不变
fn try_parse_int(data : Array[Byte], n : Int, pos : Ref[Int]) -> Int? {
  let mut p = pos.val
  let mut sign = 1
  if p < n && (data[p] == b'-' || data[p] == b'+') {
    if data[p] == b'-' {
      sign = -1
    }
    p = p + 1
  }
  if p >= n || !is_digit(data[p]) {
    return None
  }
  let mut v = 0
  while p < n && is_digit(data[p]) {
    v = v * 10 + (data[p].to_int() - 48)
    p = p + 1
  }
  pos.val = p
  Some(sign * v)
}

///|
/// 前进并吞掉一个数字字面量（整数 / 实数 / 科学计数），不返回其值
fn parse_number_token(data : Array[Byte], n : Int, pos : Ref[Int]) -> Unit {
  if pos.val < n && (data[pos.val] == b'-' || data[pos.val] == b'+') {
    pos.val = pos.val + 1
  }
  while pos.val < n && is_digit(data[pos.val]) {
    pos.val = pos.val + 1
  }
  if pos.val < n && data[pos.val] == b'.' {
    pos.val = pos.val + 1
    while pos.val < n && is_digit(data[pos.val]) {
      pos.val = pos.val + 1
    }
  }
  if pos.val < n && (data[pos.val] == b'e' || data[pos.val] == b'E') {
    pos.val = pos.val + 1
    if pos.val < n && (data[pos.val] == b'-' || data[pos.val] == b'+') {
      pos.val = pos.val + 1
    }
    while pos.val < n && is_digit(data[pos.val]) {
      pos.val = pos.val + 1
    }
  }
}

// ============================================================
// 字符级辅助
// ============================================================

///|
fn pdf_skip_ws(data : Array[Byte], n : Int, pos : Ref[Int]) -> Unit {
  while pos.val < n {
    let c = data[pos.val]
    if c == b' ' ||
      c == b'\n' ||
      c == b'\r' ||
      c == b'\t' ||
      c == b'\x0c' ||
      c == b'\x00' {
      pos.val = pos.val + 1
    } else if c == b'%' {
      while pos.val < n && data[pos.val] != b'\n' && data[pos.val] != b'\r' {
        pos.val = pos.val + 1
      }
    } else {
      break
    }
  }
}

///|
fn is_ws_byte(c : Byte) -> Bool {
  c == b' ' ||
  c == b'\n' ||
  c == b'\r' ||
  c == b'\t' ||
  c == b'\x0c' ||
  c == b'\x00'
}

///|
fn is_digit(c : Byte) -> Bool {
  let v = c.to_int()
  v >= '0'.to_int() && v <= '9'.to_int()
}

///|
fn is_delim(c : Byte) -> Bool {
  is_ws_byte(c) ||
  c == b'(' ||
  c == b')' ||
  c == b'<' ||
  c == b'>' ||
  c == b'[' ||
  c == b']' ||
  c == b'{' ||
  c == b'}' ||
  c == b'/' ||
  c == b'%'
}

///|
fn hex_val(c : Byte) -> Int {
  let v = c.to_int()
  if v >= '0'.to_int() && v <= '9'.to_int() {
    v - '0'.to_int()
  } else if v >= 'a'.to_int() && v <= 'f'.to_int() {
    v - 'a'.to_int() + 10
  } else if v >= 'A'.to_int() && v <= 'F'.to_int() {
    v - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// 判断 pos 处是否为单词 word 且后面是分隔符（不前进）
fn matches_word(
  data : Array[Byte],
  n : Int,
  pos : Ref[Int],
  word : String,
) -> Bool {
  let w = word.iter().to_array()
  let k = w.length()
  if pos.val + k > n {
    return false
  }
  let mut j = 0
  while j < k {
    if data[pos.val + j].to_int() != w[j].to_int() {
      return false
    }
    j = j + 1
  }
  if pos.val + k < n && !is_delim(data[pos.val + k]) {
    return false
  }
  true
}

// ============================================================
// 对象导航
// ============================================================

///|
fn lookup(doc : PdfDoc, num : Int) -> PdfObject raise ReaderError {
  for kv in doc.objects {
    let (n, o) = kv
    if n == num {
      return o
    }
  }
  raise ReaderError::Parse("PDF 未找到对象 " + num.to_string())
}

///|
/// 解析间接引用（只跟随一层）
fn resolve(doc : PdfDoc, v : PdfValue) -> PdfValue raise ReaderError {
  match v {
    PRef(n, _) => lookup(doc, n).value
    _ => v
  }
}

///|
/// 把值解析为间接对象（引用则取对象本身）
fn resolve_obj(doc : PdfDoc, v : PdfValue) -> PdfObject raise ReaderError {
  match v {
    PRef(n, _) => lookup(doc, n)
    _ => { value: v, stream: None }
  }
}

///|
/// 取字典中 key 对应的字典（自动解析引用），不存在返回 None
fn field_dict(
  doc : PdfDoc,
  dict : Array[(String, PdfValue)],
  key : String,
) -> Array[(String, PdfValue)]? raise ReaderError {
  match dict_get(dict, key) {
    Some(v) =>
      match resolve(doc, v) {
        PDict(kv) => Some(kv)
        _ => None
      }
    None => None
  }
}

///|
fn dict_get(dict : Array[(String, PdfValue)], key : String) -> PdfValue? {
  for kv in dict {
    let (k, v) = kv
    if k == key {
      return Some(v)
    }
  }
  None
}

///|
fn dict_name(dict : Array[(String, PdfValue)], key : String) -> String? {
  match dict_get(dict, key) {
    Some(PName(n)) => Some(n)
    _ => None
  }
}

///|
/// 查找 Catalog 对象号
fn get_root(doc : PdfDoc) -> Int raise ReaderError {
  for kv in doc.objects {
    let (num, obj) = kv
    match obj.value {
      PDict(kv) =>
        match dict_name(kv, "Type") {
          Some("Catalog") => return num
          _ => ()
        }
      _ => ()
    }
  }
  raise ReaderError::Parse("PDF 未找到 Catalog")
}

///|
/// 遍历页树，收集所有 /Page 对象号
fn collect_pages(doc : PdfDoc, pages_num : Int) -> Array[Int] raise ReaderError {
  let out : Array[Int] = []
  let pobj = lookup(doc, pages_num)
  let pdict = match pobj.value {
    PDict(kv) => kv
    _ => raise ReaderError::Parse("PDF Pages 对象无效")
  }
  match dict_get(pdict, "Kids") {
    Some(PArr(kids)) =>
      for kid in kids {
        match kid {
          PRef(n, _) => {
            let k = lookup(doc, n)
            match k.value {
              PDict(kv) =>
                match dict_name(kv, "Type") {
                  Some("Page") => out.push(n)
                  Some("Pages") =>
                    for p in collect_pages(doc, n) {
                      out.push(p)
                    }
                  _ => ()
                }
              _ => ()
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
  out
}

// ============================================================
// 流解码
// ============================================================

///|
/// 尝试按 zlib 解压，失败退回裸 DEFLATE，再失败返回原样
fn inflate(raw : Bytes) -> Bytes {
  let fa = raw.to_fixedarray()
  try {
    Bytes::from_array(@fzip.unzlib_sync(fa))
  } catch {
    _ =>
      try {
        Bytes::from_array(@fzip.inflate_sync(fa))
      } catch {
        _ => raw
      }
  }
}

///|
fn decode_obj_stream(obj : PdfObject) -> Bytes {
  match obj.stream {
    None => b""
    Some(raw) => inflate(raw)
  }
}

///|
/// 取页内容流字节（支持单引用或引用数组，多段拼接）
fn get_content_bytes(
  doc : PdfDoc,
  page_dict : Array[(String, PdfValue)],
) -> Bytes raise ReaderError {
  match dict_get(page_dict, "Contents") {
    None => b""
    Some(c) =>
      match c {
        PArr(items) => {
          let mut all : Bytes = b""
          for it in items {
            all = all + decode_obj_stream(resolve_obj(doc, it))
          }
          all
        }
        _ => decode_obj_stream(resolve_obj(doc, c))
      }
  }
}

// ============================================================
// 字体与 ToUnicode CMap
// ============================================================

///|
/// 构建页的字体表：字体名 → PdfFont
fn build_page_fonts(
  doc : PdfDoc,
  pdict : Array[(String, PdfValue)],
) -> Array[(String, PdfFont)] raise ReaderError {
  let out : Array[(String, PdfFont)] = []
  match field_dict(doc, pdict, "Resources") {
    Some(rd) =>
      match field_dict(doc, rd, "Font") {
        Some(fd) =>
          for kv in fd {
            let (name, fv) = kv
            out.push((name, build_font(doc, fv)))
          }
        None => ()
      }
    None => ()
  }
  out
}

///|
fn build_font(doc : PdfDoc, fv : PdfValue) -> PdfFont raise ReaderError {
  match resolve(doc, fv) {
    PDict(kv) => {
      let subtype = dict_name(kv, "Subtype")
      let encoding = dict_name(kv, "Encoding")
      let cmap = match dict_get(kv, "ToUnicode") {
        Some(tu) => parse_cmap_from(doc, tu)
        None => []
      }
      let is_cid = subtype == Some("Type0") ||
        encoding == Some("Identity-H") ||
        encoding == Some("Identity-V")
      { simple: !is_cid, cid_map: cmap }
    }
    _ => { simple: true, cid_map: [] }
  }
}

///|
/// 从 ToUnicode 引用取流、解压、解析为 (cid, unicode) 映射
fn parse_cmap_from(
  doc : PdfDoc,
  tu : PdfValue,
) -> Array[(Int, Int)] raise ReaderError {
  let obj = resolve_obj(doc, tu)
  match obj.stream {
    None => []
    Some(raw) => {
      let text = @utf8.decode_lossy(inflate(raw))
      parse_cmap(text)
    }
  }
}

///|
/// 解析 ToUnicode CMap 文本中的 bfchar / bfrange
fn parse_cmap(text : String) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let bf = cmap_region(text, "beginbfchar", "endbfchar")
  let ints = extract_hex_ints(bf)
  let mut i = 0
  while i + 1 < ints.length() {
    out.push((ints[i], ints[i + 1]))
    i = i + 2
  }
  // bfrange 只处理无数组的三元组形式 <lo> <hi> <dst>
  let br = cmap_region(text, "beginbfrange", "endbfrange")
  if !str_has(br, '[') {
    let rs = extract_hex_ints(br)
    let mut j = 0
    while j + 2 < rs.length() {
      let lo = rs[j]
      let hi = rs[j + 1]
      let dst = rs[j + 2]
      let mut k = 0
      while lo + k <= hi {
        out.push((lo + k, dst + k))
        k = k + 1
      }
      j = j + 3
    }
  }
  out
}

///|
fn cmap_region(text : String, start : String, end : String) -> String {
  let si = index_of(text, start)
  if si < 0 {
    return ""
  }
  let ei = index_of(text, end)
  if ei < 0 {
    return ""
  }
  text[si + start.length() : ei].to_owned()
}

///|
fn index_of(s : String, sub : String) -> Int {
  let sc = s.iter().to_array()
  let pc = sub.iter().to_array()
  let n = sc.length()
  let m = pc.length()
  if m == 0 {
    return 0
  }
  let mut i = 0
  while i + m <= n {
    let mut j = 0
    while j < m && sc[i + j] == pc[j] {
      j = j + 1
    }
    if j == m {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn str_has(s : String, ch : Char) -> Bool {
  for c in s {
    if c == ch {
      return true
    }
  }
  false
}

///|
/// 提取字符串中所有 <HHHH> 十六进制串对应的整数值
fn extract_hex_ints(s : String) -> Array[Int] {
  let out : Array[Int] = []
  let chars = s.iter().to_array()
  let n = chars.length()
  let mut i = 0
  while i < n {
    if chars[i] == '<' {
      let mut j = i + 1
      let mut v = 0
      let mut ok = false
      while j < n && chars[j] != '>' && hex_val_char(chars[j]) >= 0 {
        v = v * 16 + hex_val_char(chars[j])
        j = j + 1
        ok = true
      }
      if ok && j < n && chars[j] == '>' {
        out.push(v)
        i = j + 1
      } else {
        i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn hex_val_char(c : Char) -> Int {
  let v = c.to_int()
  if v >= '0'.to_int() && v <= '9'.to_int() {
    v - '0'.to_int()
  } else if v >= 'a'.to_int() && v <= 'f'.to_int() {
    v - 'a'.to_int() + 10
  } else if v >= 'A'.to_int() && v <= 'F'.to_int() {
    v - 'A'.to_int() + 10
  } else {
    -1
  }
}

// ============================================================
// 内容流文本提取
// ============================================================

///|
/// 把内容流字节按 PDF 值切分成 token 序列
fn tokenize_content(content : Bytes) -> Array[PdfValue] raise ReaderError {
  let data = content.to_array()
  let n = data.length()
  let pos = @ref.new(0)
  let out : Array[PdfValue] = []
  while pos.val < n {
    pdf_skip_ws(data, n, pos)
    if pos.val >= n {
      break
    }
    out.push(parse_value(data, n, pos))
  }
  out
}

///|
/// 提取内容流中的文本片段，按当前字体解码
fn extract_text(
  content : Bytes,
  fonts : Array[(String, PdfFont)],
) -> Array[String] raise ReaderError {
  let tokens = tokenize_content(content)
  let runs : Array[String] = []
  let mut current_font = "F1"
  let n = tokens.length()
  let mut i = 0
  while i < n {
    match tokens[i] {
      PName(op) => {
        if op == "Tf" && i >= 2 {
          match tokens[i - 2] {
            PName(fname) => current_font = fname
            _ => ()
          }
        } else if op == "Tj" && i >= 1 {
          match tokens[i - 1] {
            PStr(s) => runs.push(decode_with_font(fonts, current_font, s))
            _ => ()
          }
        } else if op == "TJ" && i >= 1 {
          match tokens[i - 1] {
            PArr(a) => {
              let mut sb = ""
              for el in a {
                match el {
                  PStr(s) => sb = sb + decode_with_font(fonts, current_font, s)
                  _ => ()
                }
              }
              if sb != "" {
                runs.push(sb)
              }
            }
            _ => ()
          }
        } else if (op == "'" || op == "\"") && i >= 1 {
          match tokens[i - 1] {
            PStr(s) => runs.push(decode_with_font(fonts, current_font, s))
            _ => ()
          }
        }
      }
      _ => ()
    }
    i = i + 1
  }
  runs
}

///|
fn decode_with_font(
  fonts : Array[(String, PdfFont)],
  name : String,
  s : Bytes,
) -> String {
  let font = match find_font(fonts, name) {
    Some(f) => f
    None => { simple: true, cid_map: [] }
  }
  decode_run(font, s)
}

///|
fn find_font(
  fonts : Array[(String, PdfFont)],
  name : String,
) -> PdfFont? {
  for kv in fonts {
    let (n, f) = kv
    if n == name {
      return Some(f)
    }
  }
  None
}

///|
/// 按字体解码一段字节为字符串
fn decode_run(font : PdfFont, bytes : Bytes) -> String {
  let arr = bytes.to_array()
  let chars : Array[Char] = []
  if font.simple {
    for b in arr {
      chars.push(b.to_int().unsafe_to_char())
    }
  } else {
    let mut i = 0
    while i + 1 < arr.length() {
      let cid = (arr[i].to_int() << 8) | arr[i + 1].to_int()
      let uni = lookup_cid(font.cid_map, cid)
      if uni >= 0 {
        chars.push(uni.unsafe_to_char())
      }
      i = i + 2
    }
  }
  String::from_array(chars)
}

///|
fn lookup_cid(map : Array[(Int, Int)], cid : Int) -> Int {
  for kv in map {
    let (c, u) = kv
    if c == cid {
      return u
    }
  }
  -1
}
