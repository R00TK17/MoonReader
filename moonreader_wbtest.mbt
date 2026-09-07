// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

// ============================================================
// XML 内部辅助函数（xml.mbt）
// ============================================================

///|
test "decode_entities 解码五个命名实体" {
  assert_eq(decode_entities("&lt;"), "<")
  assert_eq(decode_entities("&gt;"), ">")
  assert_eq(decode_entities("&amp;"), "&")
  assert_eq(decode_entities("&quot;"), "\"")
  assert_eq(decode_entities("&apos;"), "'")
  assert_eq(decode_entities("&lt;&gt;&amp;&quot;&apos;"), "<>&\"'")
}

///|
test "decode_entities 未知/未闭合实体原样保留" {
  assert_eq(decode_entities("&foo;"), "&foo;")
  assert_eq(decode_entities("&amp"), "&amp")
  assert_eq(decode_entities("&amp;lt;"), "&lt;") // 只解一层：&amp; → &，lt; 保留
  assert_eq(decode_entities("a&amp;b"), "a&b")
  assert_eq(decode_entities(""), "")
}

///|
test "entity_at 匹配与越界判断" {
  let amp = "&amp;".iter().to_array()
  assert_eq(entity_at(amp, amp.length(), 0, "amp"), true)
  assert_eq(entity_at(amp, amp.length(), 0, "lt"), false)
  // 缺少结尾分号 → 长度不足，越界返回 false
  let short = "&amp".iter().to_array()
  assert_eq(entity_at(short, short.length(), 0, "amp"), false)
  // 非 & 开头
  let plain = "amp;".iter().to_array()
  assert_eq(entity_at(plain, plain.length(), 0, "amp"), false)
}

///|
test "is_comment_start / is_cdata_start 边界" {
  let c1 = "<!--x".iter().to_array()
  assert_eq(is_comment_start(c1, c1.length(), 0), true)
  let c2 = "<!-x".iter().to_array()
  assert_eq(is_comment_start(c2, c2.length(), 0), false)
  let d1 = "<![CDATA[x]]>".iter().to_array()
  assert_eq(is_cdata_start(d1, d1.length(), 0), true)
  let d2 = "<![CDAT".iter().to_array()
  assert_eq(is_cdata_start(d2, d2.length(), 0), false)
}

///|
test "is_ws / is_blank 空白判断" {
  assert_eq(is_ws(' '), true)
  assert_eq(is_ws('\t'), true)
  assert_eq(is_ws('a'), false)
  assert_eq(is_blank("   \n\t"), true)
  assert_eq(is_blank(" a "), false)
  assert_eq(is_blank(""), true)
}

// ============================================================
// Markdown 内部辅助函数（markdown.mbt）
// ============================================================

///|
test "parse_heading 解析标题级别" {
  assert_eq(parse_heading("# 标题"), Some((1, "标题")))
  assert_eq(parse_heading("### H3"), Some((3, "H3")))
  assert_eq(parse_heading("无标题"), None)
  assert_eq(parse_heading("####### 七级"), None) // > 6 级
  assert_eq(parse_heading("#无空格"), None) // # 后必须接空白
}

///|
test "is_horizontal_rule 判断水平线" {
  assert_eq(is_horizontal_rule("---"), true)
  assert_eq(is_horizontal_rule("***"), true)
  assert_eq(is_horizontal_rule("___"), true)
  assert_eq(is_horizontal_rule("----"), true)
  assert_eq(is_horizontal_rule("--"), false) // 长度 < 3
  assert_eq(is_horizontal_rule("-*-"), false) // 混字符
  assert_eq(is_horizontal_rule("abc"), false)
}

///|
test "list_item_text 解析列表项" {
  assert_eq(list_item_text("- 项目"), Some("项目"))
  assert_eq(list_item_text("* star"), Some("star"))
  assert_eq(list_item_text("+ plus"), Some("plus"))
  assert_eq(list_item_text("1. 有序"), Some("有序"))
  assert_eq(list_item_text("2) paren"), Some("paren"))
  assert_eq(list_item_text("普通文本"), None)
  assert_eq(list_item_text("-无空格"), None)
}
