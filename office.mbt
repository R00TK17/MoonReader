// ============================================================
// Office（OOXML：docx / xlsx / pptx）
//
// 这三种格式本质都是 ZIP 包，内部是 XML 文档：
//   docx → word/document.xml
//   xlsx → xl/worksheets/sheet1.xml + xl/sharedStrings.xml
//   pptx → ppt/slides/slideN.xml
//
// 解压交给 hustcer/fzip，XML 用内置解析器解析，这里只做文本抽取。
// ============================================================

///|
/// 读取 docx 全部文本（段落按换行拼接）
pub fn read_docx_text(path : String) -> String raise ReaderError {
  let entries = read_zip_entries(path)
  let doc = parse_xml(entry_text(entries, "word/document.xml"))
  docx_paragraphs(doc).join("\n")
}

///|
/// 读取 docx 各段落文本（每段一个字符串）
pub fn read_docx_paragraphs(path : String) -> Array[String] raise ReaderError {
  let entries = read_zip_entries(path)
  let doc = parse_xml(entry_text(entries, "word/document.xml"))
  docx_paragraphs(doc)
}

///|
/// 一个工作表：名称 + 二维表（行 → 单元格）
pub(all) struct ExcelSheet {
  name : String
  rows : Array[Array[String]]
}

///|
/// 读取 xlsx 全部工作表（含多 sheet），共享字符串已解析为文本
pub fn read_excel_sheets(path : String) -> Array[ExcelSheet] raise ReaderError {
  let entries = read_zip_entries(path)
  let shared = parse_shared_strings(entries)
  let refs = sheet_refs(entries)
  let out : Array[ExcelSheet] = []
  for kv in refs {
    let (name, target) = kv
    let sheet = parse_xml(entry_text(entries, target))
    out.push({ name, rows: sheet_rows(sheet, shared) })
  }
  out
}

///|
/// 读取 xlsx 第一个工作表为二维表（行 → 单元格），共享字符串已解析为文本
pub fn read_excel_as_rows(
  path : String,
) -> Array[Array[String]] raise ReaderError {
  let sheets = read_excel_sheets(path)
  if sheets.length() > 0 {
    return sheets[0].rows
  }
  []
}

///|
/// 读取 xlsx 第一个工作表为字符串（单元格用制表符分隔，行用换行分隔）
pub fn read_excel_as_string(path : String) -> String raise ReaderError {
  let rows = read_excel_as_rows(path)
  rows.map(fn(r) { r.join("\t") }).join("\n")
}

///|
/// 读取 pptx 每页文本（一页一个字符串）
pub fn read_pptx_text_by_slide(
  path : String,
) -> Array[String] raise ReaderError {
  let entries = read_zip_entries(path)
  let slides = slide_names(entries)
  slides.map((s) => slide_text(parse_xml(entry_text(entries, s))))
}

///|
/// 读取 pptx 全部文本（各页按换行拼接）
pub fn read_pptx_text(path : String) -> String raise ReaderError {
  read_pptx_text_by_slide(path).join("\n")
}

// ============================================================
// 内部辅助函数
// ============================================================

///|
/// 在包内条目中查找指定名称并解码为 UTF-8 字符串
fn entry_text(entries : Array[ZipEntry], name : String) -> String raise ReaderError {
  for e in entries {
    if e.name == name {
      return @utf8.decode_lossy(e.content)
    }
  }
  raise ReaderError::Parse("Office 包内未找到: " + name)
}

///|
/// 判断包内是否存在指定名称条目
fn has_entry(entries : Array[ZipEntry], name : String) -> Bool {
  for e in entries {
    if e.name == name {
      return true
    }
  }
  false
}

///|
/// 收集所有名称为 name 的后代元素（含自身）
fn collect_elems(root : XmlElement, name : String) -> Array[XmlElement] {
  let out : Array[XmlElement] = []
  collect_walk(root, name, out)
  out
}

///|
fn collect_walk(
  e : XmlElement,
  name : String,
  out : Array[XmlElement],
) -> Unit {
  if e.name == name {
    out.push(e)
  }
  for c in e.children {
    match c {
      Element(child) => collect_walk(child, name, out)
      Text(_) => ()
    }
  }
}

///|
/// docx：按段落收集 w:t 文本
fn docx_paragraphs(doc : XmlElement) -> Array[String] {
  let paras = collect_elems(doc, "w:p")
  paras.map(fn(p) {
    collect_elems(p, "w:t").map(fn(t) { t.text() }).join("")
  })
}

///|
/// xlsx：解析共享字符串表，返回按索引排列的字符串数组（无表则为空）
fn parse_shared_strings(entries : Array[ZipEntry]) -> Array[String] raise ReaderError {
  if !has_entry(entries, "xl/sharedStrings.xml") {
    return []
  }
  let sst = parse_xml(entry_text(entries, "xl/sharedStrings.xml"))
  let sis = collect_elems(sst, "si")
  sis.map(fn(si) { collect_elems(si, "t").map(fn(t) { t.text() }).join("") })
}

///|
/// xlsx：从 workbook.xml + 关系表解析出 (工作表名, 表文件路径) 列表，按显示顺序
fn sheet_refs(entries : Array[ZipEntry]) -> Array[(String, String)] raise ReaderError {
  if !has_entry(entries, "xl/workbook.xml") {
    return [("Sheet1", "xl/worksheets/sheet1.xml")]
  }
  let wb = parse_xml(entry_text(entries, "xl/workbook.xml"))
  let sheets = collect_elems(wb, "sheet")
  // 关系表：Id -> Target（Target 相对 xl/ 目录）
  let rels : Array[(String, String)] = []
  if has_entry(entries, "xl/_rels/workbook.xml.rels") {
    let rel_doc = parse_xml(entry_text(entries, "xl/_rels/workbook.xml.rels"))
    for rel in collect_elems(rel_doc, "Relationship") {
      let id = match rel.attr("Id") {
        Some(v) => v
        None => continue
      }
      let target = match rel.attr("Target") {
        Some(v) => v
        None => continue
      }
      rels.push((id, target))
    }
  }
  let out : Array[(String, String)] = []
  let mut i = 1
  for s in sheets {
    let name = match s.attr("name") {
      Some(n) => n
      None => "Sheet" + i.to_string()
    }
    let target = match s.attr("r:id") {
      Some(rid) => resolve_target(rels, rid)
      None => ""
    }
    let full = if target == "" {
      "xl/worksheets/sheet" + i.to_string() + ".xml"
    } else {
      "xl/" + target
    }
    out.push((name, full))
    i = i + 1
  }
  if out.length() > 0 {
    return out
  }
  [("Sheet1", "xl/worksheets/sheet1.xml")]
}

///|
/// xlsx：在关系表中按 Id 查找 Target
fn resolve_target(rels : Array[(String, String)], id : String) -> String {
  for kv in rels {
    let (rid, target) = kv
    if rid == id {
      return target
    }
  }
  ""
}

///|
/// xlsx：把 sheet 解析为二维表
fn sheet_rows(
  sheet : XmlElement,
  shared : Array[String],
) -> Array[Array[String]] {
  let rows = collect_elems(sheet, "row")
  rows.map(fn(r) { collect_elems(r, "c").map(fn(c) { cell_text(c, shared) }) })
}

///|
/// xlsx：读取单个单元格文本（支持共享字符串 / 内联字符串 / 数字 / 布尔）
fn cell_text(c : XmlElement, shared : Array[String]) -> String {
  match c.attr("t") {
    Some("s") => {
      let vs = collect_elems(c, "v")
      if vs.length() > 0 {
        let idx = parse_int(vs[0].text())
        if idx >= 0 && idx < shared.length() {
          return shared[idx]
        }
      }
      ""
    }
    Some("inlineStr") => {
      collect_elems(c, "t").map(fn(t) { t.text() }).join("")
    }
    _ => {
      let vs = collect_elems(c, "v")
      if vs.length() > 0 {
        return vs[0].text()
      }
      let ts = collect_elems(c, "t")
      if ts.length() > 0 {
        return ts[0].text()
      }
      ""
    }
  }
}

///|
/// pptx：按编号升序收集幻灯片文件名
fn slide_names(entries : Array[ZipEntry]) -> Array[String] {
  let names : Array[String] = []
  for e in entries {
    if e.name.has_prefix("ppt/slides/slide".view()) &&
      e.name.has_suffix(".xml".view()) {
      names.push(e.name)
    }
  }
  names.sort_by(fn(a, b) { slide_number(a) - slide_number(b) })
  names
}

///|
/// pptx：从文件名提取幻灯片编号，如 "ppt/slides/slide12.xml" → 12
fn slide_number(name : String) -> Int {
  let n = name.length()
  let mut v = 0
  let mut i = 0
  while i < n {
    let ch = name[i]
    if ch >= '0' && ch <= '9' {
      v = v * 10 + (ch.to_int() - '0'.to_int())
    } else if ch == '.' {
      break
    } else {
      v = 0
    }
    i = i + 1
  }
  v
}

///|
/// pptx：抽取单页文本（按 a:p 段落、a:t 文本）
fn slide_text(slide : XmlElement) -> String {
  let paras = collect_elems(slide, "a:p")
  paras.map(fn(p) {
    collect_elems(p, "a:t").map(fn(t) { t.text() }).join("")
  }).join("\n")
}

///|
/// 解析整数（支持可选负号），供共享字符串索引、幻灯片编号等使用
fn parse_int(s : String) -> Int {
  let n = s.length()
  let mut i = 0
  let mut sign = 1
  if n > 0 && s[0] == '-' {
    sign = -1
    i = 1
  }
  let mut v = 0
  while i < n {
    let ch = s[i]
    if ch >= '0' && ch <= '9' {
      v = v * 10 + (ch.to_int() - '0'.to_int())
    } else {
      break
    }
    i = i + 1
  }
  sign * v
}
