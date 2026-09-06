// ============================================================
// XML
// ============================================================
// 一个轻量、纯 MoonBit 的 XML 解析器：把文档解析成元素树。
// 支持：XML 声明、DOCTYPE、注释、CDATA、处理指令、自闭合标签、
//       单/双引号属性、命名实体（&lt; &gt; &amp; &quot; &apos;）。
// 限制：忽略命名空间前缀解析、不校验 DTD；数字实体（&#NN;）原样保留。

///|
/// XML 节点：文本或子元素
pub(all) enum XmlNode {
  Text(String)
  Element(XmlElement)
}

///|
/// XML 元素：标签名 + 属性 + 子节点
pub(all) struct XmlElement {
  name : String
  attrs : Array[(String, String)]
  children : Array[XmlNode]
}

///|
/// 读取并解析 XML 文件，返回根元素
pub fn read_xml(
  file_path : String,
  encoding? : Encoding? = None,
) -> XmlElement raise ReaderError {
  parse_xml(read_txt(file_path, encoding~))
}

///|
/// 解析 XML 字符串，返回根元素
pub fn parse_xml(text : String) -> XmlElement raise ReaderError {
  let chars = text.iter().to_array()
  let n = chars.length()
  let pos = @ref.new(0)
  skip_misc(chars, n, pos)
  if pos.val >= n || chars[pos.val] != '<' {
    raise ReaderError::Parse("XML 缺少根元素")
  }
  parse_element(chars, n, pos)
}

///|
/// 该元素的全部文本内容（含子孙文本节点，按顺序拼接）
pub fn XmlElement::text(self : XmlElement) -> String {
  let mut s = ""
  for c in self.children {
    match c {
      Text(t) => s = s + t
      Element(child) => s = s + child.text()
    }
  }
  s
}

///|
/// 按属性名取值，不存在返回 None
pub fn XmlElement::attr(self : XmlElement, key : String) -> String? {
  for kv in self.attrs {
    let (k, v) = kv
    if k == key {
      return Some(v)
    }
  }
  None
}

///|
/// 渲染为带缩进的 XML 字符串（用于展示）
pub fn XmlElement::to_string(self : XmlElement) -> String {
  render_element(self, 0)
}

// ============================================================
// 内部解析辅助函数
// ============================================================

///|
fn is_ws(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn skip_ws(chars : Array[Char], n : Int, pos : Ref[Int]) -> Unit {
  while pos.val < n && is_ws(chars[pos.val]) {
    pos.val = pos.val + 1
  }
}

///|
fn is_name_char(c : Char) -> Bool {
  !is_ws(c) &&
  c != '<' &&
  c != '>' &&
  c != '/' &&
  c != '=' &&
  c != '\'' &&
  c != '"'
}

///|
/// 宽松读取名称：遇到空白或 < > / = 引号 之一时停止，可读中文等非 ASCII 名称
fn read_name(chars : Array[Char], n : Int, pos : Ref[Int]) -> String {
  let buf : Array[Char] = []
  while pos.val < n && is_name_char(chars[pos.val]) {
    buf.push(chars[pos.val])
    pos.val = pos.val + 1
  }
  String::from_array(buf)
}

///|
/// 跳过 XML 声明、注释、DOCTYPE 等顶层杂项，停在根元素 '<' 处
fn skip_misc(chars : Array[Char], n : Int, pos : Ref[Int]) -> Unit {
  while pos.val < n {
    skip_ws(chars, n, pos)
    if pos.val >= n {
      return
    }
    if chars[pos.val] != '<' {
      return
    }
    if is_comment_start(chars, n, pos.val) {
      skip_comment(chars, n, pos)
    } else if is_cdata_start(chars, n, pos.val) {
      skip_until_gt(chars, n, pos)
    } else if pos.val + 1 < n &&
      (chars[pos.val + 1] == '!' || chars[pos.val + 1] == '?') {
      skip_until_gt(chars, n, pos)
    } else {
      return // 真正的根元素
    }
  }
}

///|
/// 解析一个元素，入口处 pos.val 指向 '<'
fn parse_element(
  chars : Array[Char],
  n : Int,
  pos : Ref[Int],
) -> XmlElement raise ReaderError {
  pos.val = pos.val + 1 // 跳过 '<'
  let name = read_name(chars, n, pos)
  if name == "" {
    raise ReaderError::Parse("XML 元素名称为空")
  }
  let attrs = read_attrs(chars, n, pos)
  skip_ws(chars, n, pos)
  if pos.val < n && chars[pos.val] == '/' {
    pos.val = pos.val + 1
    skip_ws(chars, n, pos)
    if pos.val < n && chars[pos.val] == '>' {
      pos.val = pos.val + 1
    }
    return { name, attrs, children: [], }
  }
  if pos.val < n && chars[pos.val] == '>' {
    pos.val = pos.val + 1
    let children = parse_children(chars, n, pos, name)
    return { name, attrs, children, }
  }
  raise ReaderError::Parse("XML 元素 <" + name + "> 格式错误")
}

///|
/// 解析属性列表，直到 '>' 或 '/>'；支持 name="value" 与布尔属性
fn read_attrs(
  chars : Array[Char],
  n : Int,
  pos : Ref[Int],
) -> Array[(String, String)] raise ReaderError {
  let attrs : Array[(String, String)] = []
  while pos.val < n {
    skip_ws(chars, n, pos)
    if pos.val >= n {
      break
    }
    let c = chars[pos.val]
    if c == '>' || c == '/' || c == '?' {
      break
    }
    let an = read_name(chars, n, pos)
    if an == "" {
      break
    }
    skip_ws(chars, n, pos)
    if pos.val < n && chars[pos.val] == '=' {
      pos.val = pos.val + 1
      let av = read_attr_value(chars, n, pos)
      attrs.push((an, av))
    } else {
      attrs.push((an, "")) // 无值属性
    }
  }
  attrs
}

///|
fn read_attr_value(
  chars : Array[Char],
  n : Int,
  pos : Ref[Int],
) -> String raise ReaderError {
  skip_ws(chars, n, pos)
  if pos.val >= n {
    return ""
  }
  let quote = chars[pos.val]
  if quote != '"' && quote != '\'' {
    raise ReaderError::Parse("XML 属性值缺少引号")
  }
  pos.val = pos.val + 1
  let buf : Array[Char] = []
  while pos.val < n && chars[pos.val] != quote {
    buf.push(chars[pos.val])
    pos.val = pos.val + 1
  }
  if pos.val < n {
    pos.val = pos.val + 1 // 跳过结束引号
  }
  decode_entities(String::from_array(buf))
}

///|
/// 解析子节点，直到遇到匹配的闭合标签 </parent_name>
fn parse_children(
  chars : Array[Char],
  n : Int,
  pos : Ref[Int],
  parent_name : String,
) -> Array[XmlNode] raise ReaderError {
  let children : Array[XmlNode] = []
  while pos.val < n {
    let text = read_text(chars, n, pos)
    if text != "" && !is_blank(text) {
      children.push(XmlNode::Text(decode_entities(text)))
    }
    if pos.val >= n {
      break
    }
    // 此时 chars[pos.val] == '<'
    if pos.val + 1 < n && chars[pos.val + 1] == '/' {
      if is_closing(chars, n, pos, parent_name) {
        skip_closing(chars, n, pos)
        return children
      }
      raise ReaderError::Parse(
        "XML 标签不匹配: 期望 </" + parent_name + ">",
      )
    }
    if is_comment_start(chars, n, pos.val) {
      skip_comment(chars, n, pos)
      continue
    }
    if is_cdata_start(chars, n, pos.val) {
      children.push(XmlNode::Text(read_cdata(chars, n, pos)))
      continue
    }
    if pos.val + 1 < n &&
      (chars[pos.val + 1] == '!' || chars[pos.val + 1] == '?') {
      skip_until_gt(chars, n, pos)
      continue
    }
    children.push(XmlNode::Element(parse_element(chars, n, pos)))
  }
  raise ReaderError::Parse(
    "XML 元素 <" + parent_name + "> 缺少闭合标签",
  )
}

///|
/// 读取文本直到下一个 '<'
fn read_text(chars : Array[Char], n : Int, pos : Ref[Int]) -> String {
  let buf : Array[Char] = []
  while pos.val < n && chars[pos.val] != '<' {
    buf.push(chars[pos.val])
    pos.val = pos.val + 1
  }
  String::from_array(buf)
}

///|
fn is_blank(s : String) -> Bool {
  for c in s {
    if !is_ws(c) {
      return false
    }
  }
  true
}

///|
/// 判断 pos 处是否为 </parent_name>
fn is_closing(
  chars : Array[Char],
  n : Int,
  pos : Ref[Int],
  parent_name : String,
) -> Bool {
  let i = pos.val
  if i + 1 >= n || chars[i] != '<' || chars[i + 1] != '/' {
    return false
  }
  let pn = parent_name.iter().to_array()
  let k = pn.length()
  if i + 2 + k > n {
    return false
  }
  let mut j = 0
  while j < k {
    if chars[i + 2 + j] != pn[j] {
      return false
    }
    j = j + 1
  }
  let after = i + 2 + k
  if after < n {
    let c = chars[after]
    if c != '>' && c != '/' && !is_ws(c) {
      return false
    }
  }
  true
}

///|
fn skip_closing(chars : Array[Char], n : Int, pos : Ref[Int]) -> Unit {
  pos.val = pos.val + 2 // 跳过 '</'
  while pos.val < n && chars[pos.val] != '>' {
    pos.val = pos.val + 1
  }
  if pos.val < n {
    pos.val = pos.val + 1
  }
}

///|
fn skip_until_gt(chars : Array[Char], n : Int, pos : Ref[Int]) -> Unit {
  while pos.val < n && chars[pos.val] != '>' {
    pos.val = pos.val + 1
  }
  if pos.val < n {
    pos.val = pos.val + 1
  }
}

///|
fn skip_comment(chars : Array[Char], n : Int, pos : Ref[Int]) -> Unit {
  pos.val = pos.val + 4 // 跳过 '<!--'
  while pos.val + 2 < n {
    if chars[pos.val] == '-' &&
      chars[pos.val + 1] == '-' &&
      chars[pos.val + 2] == '>' {
      pos.val = pos.val + 3
      return
    }
    pos.val = pos.val + 1
  }
  pos.val = n
}

///|
fn read_cdata(chars : Array[Char], n : Int, pos : Ref[Int]) -> String {
  pos.val = pos.val + 9 // 跳过 '<![CDATA['
  let buf : Array[Char] = []
  while pos.val + 2 < n {
    if chars[pos.val] == ']' &&
      chars[pos.val + 1] == ']' &&
      chars[pos.val + 2] == '>' {
      pos.val = pos.val + 3
      break
    }
    buf.push(chars[pos.val])
    pos.val = pos.val + 1
  }
  String::from_array(buf)
}

///|
fn is_comment_start(chars : Array[Char], n : Int, i : Int) -> Bool {
  i + 4 <= n &&
  chars[i] == '<' &&
  chars[i + 1] == '!' &&
  chars[i + 2] == '-' &&
  chars[i + 3] == '-'
}

///|
fn is_cdata_start(chars : Array[Char], n : Int, i : Int) -> Bool {
  i + 9 <= n &&
  chars[i] == '<' &&
  chars[i + 1] == '!' &&
  chars[i + 2] == '[' &&
  chars[i + 3] == 'C' &&
  chars[i + 4] == 'D' &&
  chars[i + 5] == 'A' &&
  chars[i + 6] == 'T' &&
  chars[i + 7] == 'A' &&
  chars[i + 8] == '['
}

// ============================================================
// 实体解码
// ============================================================

///|
fn decode_entities(s : String) -> String {
  let chars = s.iter().to_array()
  let n = chars.length()
  let buf : Array[Char] = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    if c == '&' && entity_at(chars, n, i, "lt") {
      buf.push('<')
      i = i + 4
    } else if c == '&' && entity_at(chars, n, i, "gt") {
      buf.push('>')
      i = i + 4
    } else if c == '&' && entity_at(chars, n, i, "amp") {
      buf.push('&')
      i = i + 5
    } else if c == '&' && entity_at(chars, n, i, "quot") {
      buf.push('"')
      i = i + 6
    } else if c == '&' && entity_at(chars, n, i, "apos") {
      buf.push('\'')
      i = i + 6
    } else {
      buf.push(c)
      i = i + 1
    }
  }
  String::from_array(buf)
}

///|
/// 判断 chars[i] 处是否为 "&name;"
fn entity_at(chars : Array[Char], n : Int, i : Int, name : String) -> Bool {
  let nc = name.iter().to_array()
  let k = nc.length()
  if i + k + 2 > n {
    return false
  }
  if chars[i] != '&' {
    return false
  }
  let mut j = 0
  while j < k {
    if chars[i + 1 + j] != nc[j] {
      return false
    }
    j = j + 1
  }
  chars[i + 1 + k] == ';'
}

// ============================================================
// 渲染辅助
// ============================================================

///|
fn render_element(e : XmlElement, depth : Int) -> String {
  let ind = indent_str(depth)
  let attrs = render_attrs(e.attrs)
  if e.children.length() == 0 {
    return ind + "<" + e.name + attrs + " />"
  }
  let mut s = ind + "<" + e.name + attrs + ">"
  let mut has_elem = false
  for c in e.children {
    match c {
      Text(_) => ()
      Element(_) => has_elem = true
    }
  }
  if has_elem {
    for c in e.children {
      match c {
        Text(t) => if !is_blank(t) { s = s + "\n" + indent_str(depth + 1) + t }
        Element(child) => s = s + "\n" + render_element(child, depth + 1)
      }
    }
    s = s + "\n" + ind + "</" + e.name + ">"
  } else {
    for c in e.children {
      match c {
        Text(t) => s = s + t
        _ => ()
      }
    }
    s = s + "</" + e.name + ">"
  }
  s
}

///|
fn indent_str(depth : Int) -> String {
  let mut s = ""
  let mut i = 0
  while i < depth {
    s = s + "  "
    i = i + 1
  }
  s
}

///|
fn render_attrs(attrs : Array[(String, String)]) -> String {
  let mut s = ""
  for kv in attrs {
    let (k, v) = kv
    s = s + " " + k + "=\"" + v + "\""
  }
  s
}
