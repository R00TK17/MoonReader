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
    @moonreader.detect_format("data/a.md"),
    @moonreader.FileFormat::Markdown,
  )
  assert_eq(
    @moonreader.detect_format("data/a.zip"),
    @moonreader.FileFormat::Zip,
  )
  assert_eq(
    @moonreader.detect_format("data/a.tar"),
    @moonreader.FileFormat::Tar,
  )
  assert_eq(
    @moonreader.detect_format("data/a.txt"),
    @moonreader.FileFormat::Txt,
  )
  assert_eq(
    @moonreader.detect_format("data/a.docx"),
    @moonreader.FileFormat::Docx,
  )
  assert_eq(
    @moonreader.detect_format("data/a.xlsx"),
    @moonreader.FileFormat::Xlsx,
  )
  assert_eq(
    @moonreader.detect_format("data/a.pptx"),
    @moonreader.FileFormat::Pptx,
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

///|
test "parse_markdown 解析块结构" {
  let blocks = @moonreader.parse_markdown(
    "# 标题\n\n- 项目一\n- 项目二\n\n```moonbit\nprintln(\"hi\")\n```",
  )
  assert_eq(blocks.length(), 4)
  match blocks[0] {
    @moonreader.MarkdownBlock::Heading(level, text) => {
      assert_eq(level, 1)
      assert_eq(text, "标题")
    }
    _ => abort("应为标题")
  }
  match blocks[1] {
    @moonreader.MarkdownBlock::ListItem(item) => assert_eq(item, "项目一")
    _ => abort("应为列表项")
  }
  match blocks[3] {
    @moonreader.MarkdownBlock::CodeBlock(lang, code) => {
      assert_eq(lang, "moonbit")
      assert_eq(code, "println(\"hi\")")
    }
    _ => abort("应为代码块")
  }
}

///|
test "read_zip 列出并读取包内文件" {
  let names = @moonreader.list_zip_filenames("testdata/sample.zip")
  assert_eq(names.length(), 4)
  assert_eq(names[0], "sample.jsonl")
  assert_eq(names[1], "sample.md")
  assert_eq(names[2], "sample.txt")
  assert_eq(names[3], "sample.json")
  let text = @moonreader.read_zip_text("testdata/sample.zip", "sample.txt")
  assert_eq(text, "hello world\nmoonbit file reader\n第三行内容\n")
}

///|
test "read_docx_text 读取 Word 文档段落" {
  let paras = @moonreader.read_docx_paragraphs("testdata/sample.docx")
  assert_eq(paras.length(), 3)
  assert_eq(paras[0], "何庄")
  assert_eq(paras[1], "秋雨")
  assert_eq(paras[2], "21wq")
  assert_eq(
    @moonreader.read_docx_text("testdata/sample.docx"),
    "何庄\n秋雨\n21wq",
  )
}

///|
test "read_excel_as_rows 读取 Excel 表格" {
  let rows = @moonreader.read_excel_as_rows("testdata/sample.xlsx")
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].length(), 2)
  assert_eq(rows[0][0], "何庄")
  assert_eq(rows[0][1], "hz")
  assert_eq(rows[1][0], "长沙理工大学")
  assert_eq(rows[1][1], "csust")
  assert_eq(rows[2][0], "计通学院")
  assert_eq(rows[2][1], "it_pioneer")
}

///|
test "read_excel_sheets 读取多 sheet" {
  let sheets = @moonreader.read_excel_sheets("testdata/sample.xlsx")
  assert_eq(sheets.length(), 2)
  assert_eq(sheets[0].name, "Sheet1")
  assert_eq(sheets[0].rows.length(), 3)
  assert_eq(sheets[0].rows[0][0], "何庄")
  assert_eq(sheets[1].name, "Sheet2")
  assert_eq(sheets[1].rows.length(), 2)
  assert_eq(sheets[1].rows[0][0], "科比")
  assert_eq(sheets[1].rows[0][1], "213")
  assert_eq(sheets[1].rows[1][0], "秋雨")
  assert_eq(sheets[1].rows[1][1], "ad")
}

///|
test "read_pptx_text 读取 PPT 每页文本" {
  let slides = @moonreader.read_pptx_text_by_slide("testdata/sample.pptx")
  assert_eq(slides.length(), 3)
  assert_eq(slides[0], "何庄")
  assert_eq(slides[1], "秋雨")
  assert_eq(slides[2], "何庄1213asdf")
  assert_eq(
    @moonreader.read_pptx_text("testdata/sample.pptx"),
    "何庄\n秋雨\n何庄1213asdf",
  )
}
