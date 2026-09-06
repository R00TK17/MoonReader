// Blackbox tests run against the package's public API. Use `@moonreader` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "detect_format 按扩展名识别格式" {
  assert_eq(
    @moonreader.detect_format("data/a.csv"),
    @moonreader.FileFormat::Csv,
  )
  assert_eq(
    @moonreader.detect_format("data/a.json"),
    @moonreader.FileFormat::Json,
  )
  assert_eq(
    @moonreader.detect_format("data/a.jsonl"),
    @moonreader.FileFormat::Jsonl,
  )
  assert_eq(
    @moonreader.detect_format("data/a.xml"),
    @moonreader.FileFormat::Xml,
  )
  assert_eq(
    @moonreader.detect_format("data/a.tar"),
    @moonreader.FileFormat::Tar,
  )
  assert_eq(
    @moonreader.detect_format("data/a.txt"),
    @moonreader.FileFormat::Txt,
  )
}

///|
test "detect_format 不区分大小写且未知扩展名按 TXT" {
  assert_eq(@moonreader.detect_format("a.JSON"), @moonreader.FileFormat::Json)
  assert_eq(@moonreader.detect_format("a.CSV"), @moonreader.FileFormat::Csv)
  assert_eq(
    @moonreader.detect_format("no_extension"),
    @moonreader.FileFormat::Txt,
  )
}

///|
test "parse_xml 解析元素树" {
  let root = @moonreader.parse_xml("<r><a x=\"1\">hi</a><b>yo</b></r>")
  assert_eq(root.name, "r")
  assert_eq(root.children.length(), 2)
  match root.children[0] {
    @moonreader.XmlNode::Element(e) => {
      assert_eq(e.name, "a")
      assert_eq(e.attr("x"), Some("1"))
      assert_eq(e.text(), "hi")
    }
    _ => abort("应解析为元素")
  }
}

///|
test "parse_xml 解析中文与实体" {
  let root = @moonreader.parse_xml(
    "<书名 作者=\"张三\">A &amp; B</书名>",
  )
  assert_eq(root.name, "书名")
  assert_eq(root.attr("作者"), Some("张三"))
  assert_eq(root.text(), "A & B")
}
