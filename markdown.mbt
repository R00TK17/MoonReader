// ============================================================
// Markdown
// ============================================================
// 一个轻量的 Markdown 块级解析器：把文档按块结构拆分。
// 支持：标题(#)、段落、代码块(```)、引用(>)、列表(-/*/+/1.)、水平线(---)。
// 限制：不解析行内样式（**粗体**、[链接] 等）与嵌套列表，仅做块级划分。

///|
/// Markdown 块：标题 / 段落 / 代码块 / 引用 / 列表项 / 水平线
pub(all) enum MarkdownBlock {
  /// 标题：级别(1-6) + 文本
  Heading(Int, String)
  /// 普通段落
  Paragraph(String)
  /// 代码块：语言标识 + 代码内容
  CodeBlock(String, String)
  /// 引用块
  Quote(String)
  /// 列表项
  ListItem(String)
  /// 水平分隔线
  HorizontalRule
} derive(Eq, @debug.Debug)

///|
/// 读取并解析 Markdown 文件为块结构
pub fn read_markdown(
  file_path : String,
  encoding? : Encoding? = None,
) -> Array[MarkdownBlock] raise ReaderError {
  parse_markdown(read_txt(file_path, encoding~))
}

///|
/// 解析 Markdown 字符串为块结构
pub fn parse_markdown(text : String) -> Array[MarkdownBlock] {
  let blocks : Array[MarkdownBlock] = []
  let lines = text.split("\n".view()).to_array()
  let n = lines.length()
  let mut i = 0
  while i < n {
    let line = lines[i].trim_end(chars="\r".view()).to_owned()
    // 空行
    if line.trim().length() == 0 {
      i = i + 1
      continue
    }
    // 代码块
    if line.has_prefix("```".view()) {
      let lang = line[3:].trim().to_owned()
      let code : Array[String] = []
      i = i + 1
      while i < n {
        let cl = lines[i].trim_end(chars="\r".view()).to_owned()
        if cl.has_prefix("```".view()) {
          i = i + 1
          break
        }
        code.push(cl)
        i = i + 1
      }
      blocks.push(MarkdownBlock::CodeBlock(lang, code.join("\n".view())))
      continue
    }
    // 标题
    match parse_heading(line) {
      Some((level, text)) => {
        blocks.push(MarkdownBlock::Heading(level, text))
        i = i + 1
        continue
      }
      None => ()
    }
    // 水平线
    if is_horizontal_rule(line) {
      blocks.push(MarkdownBlock::HorizontalRule)
      i = i + 1
      continue
    }
    // 引用
    if line.has_prefix(">".view()) {
      let quoted : Array[String] = []
      while i < n {
        let ql = lines[i].trim_end(chars="\r".view()).to_owned()
        if !ql.has_prefix(">".view()) {
          break
        }
        quoted.push(ql[1:].trim_start(chars=" ".view()).to_owned())
        i = i + 1
      }
      blocks.push(MarkdownBlock::Quote(quoted.join("\n".view())))
      continue
    }
    // 列表项
    match list_item_text(line) {
      Some(item) => {
        blocks.push(MarkdownBlock::ListItem(item))
        i = i + 1
        continue
      }
      None => ()
    }
    // 段落：收集连续的非特殊行
    let para : Array[String] = []
    while i < n {
      let pl = lines[i].trim_end(chars="\r".view()).to_owned()
      if pl.trim().length() == 0 ||
        parse_heading(pl) is Some(_) ||
        pl.has_prefix(">".view()) ||
        pl.has_prefix("```".view()) ||
        is_horizontal_rule(pl) ||
        list_item_text(pl) is Some(_) {
        break
      }
      para.push(pl)
      i = i + 1
    }
    if para.length() > 0 {
      blocks.push(MarkdownBlock::Paragraph(para.join(" ".view())))
    }
  }
  blocks
}

///|
/// 渲染为 Markdown 文本（近似还原）
pub fn MarkdownBlock::to_string(self : MarkdownBlock) -> String {
  match self {
    Heading(level, text) => hashes(level) + " " + text
    Paragraph(text) => text
    CodeBlock(lang, code) => "```" + lang + "\n" + code + "\n```"
    Quote(text) => "> " + text
    ListItem(text) => "- " + text
    HorizontalRule => "---"
  }
}

// ============================================================
// 内部辅助
// ============================================================

///|
fn is_ws_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn is_ws_prefix(s : String) -> Bool {
  for c in s {
    return is_ws_char(c)
  }
  false
}

///|
/// 解析标题：返回 (级别, 文本)，不是标题则返回 None
fn parse_heading(line : String) -> (Int, String)? {
  let mut level = 0
  for c in line {
    if c == '#' {
      level = level + 1
    } else {
      break
    }
  }
  if level == 0 || level > 6 {
    return None
  }
  let rest = line[level:].to_owned()
  if rest == "" || is_ws_prefix(rest) {
    return Some((level, rest.trim().to_owned()))
  }
  None
}

///|
/// 判断是否为水平线（--- / *** / ___，长度 ≥ 3 且全为同一字符）
fn is_horizontal_rule(line : String) -> Bool {
  let t = line.trim().to_owned()
  if t.length() < 3 {
    return false
  }
  let first = t[0:1].to_owned()
  if first != "-" && first != "*" && first != "_" {
    return false
  }
  for c in t {
    if c.to_string() != first {
      return false
    }
  }
  true
}

///|
/// 解析列表项：返回去掉标记后的文本，不是列表项则返回 None
fn list_item_text(line : String) -> String? {
  // 无序：- / * / + 后接空白
  if line.length() >= 2 &&
    (
      line.has_prefix("-".view()) ||
      line.has_prefix("*".view()) ||
      line.has_prefix("+".view())
    ) {
    let rest = line[1:].to_owned()
    if rest == "" || is_ws_prefix(rest) {
      return Some(line[2:].trim().to_owned())
    }
  }
  // 有序：数字 + '.' / ')' 后接内容
  let mut d = 0
  for c in line {
    if c >= '0' && c <= '9' {
      d = d + 1
    } else {
      break
    }
  }
  if d > 0 && d + 1 < line.length() {
    let sep = line[d:d + 1].to_owned()
    if sep == "." || sep == ")" {
      return Some(line[d + 1:].trim().to_owned())
    }
  }
  None
}

///|
fn hashes(n : Int) -> String {
  let mut s = ""
  let mut i = 0
  while i < n {
    s = s + "#"
    i = i + 1
  }
  s
}
