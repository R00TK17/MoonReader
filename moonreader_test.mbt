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
  assert_eq(
    @moonreader.detect_format("data/a.pdf"),
    @moonreader.FileFormat::Pdf,
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
test "XmlElement::find_all 与 find 遍历查找" {
  let root = @moonreader.parse_xml("<r><a>1</a><b><a>2</a></b></r>")
  let found = root.find_all("a")
  assert_eq(found.length(), 2)
  assert_eq(found[0].text(), "1")
  assert_eq(found[1].text(), "2")
  match root.find("b") {
    Some(e) => assert_eq(e.name, "b")
    None => abort("应找到 b")
  }
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
test "read() 统一入口返回 zip 条目内容" {
  match @moonreader.read("testdata/sample.zip") {
    @moonreader.Content::ZipFiles(entries) => {
      assert_eq(entries.length(), 4)
      assert_eq(entries[0].name, "sample.jsonl")
    }
    _ => abort("应为 ZipFiles")
  }
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
test "read_excel_first_sheet_rows 读取第一个工作表" {
  let rows = @moonreader.read_excel_first_sheet_rows("testdata/sample.xlsx")
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
test "read_excel_sheet_rows 读取指定下标工作表" {
  let rows = @moonreader.read_excel_sheet_rows("testdata/sample.xlsx", 1)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0][0], "科比")
  assert_eq(rows[0][1], "213")
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

///|
test "read_pdf_text 读取 PDF 每页文本" {
  let pages = @moonreader.read_pdf_text_by_page("testdata/sample.pdf")
  assert_eq(pages.length(), 3)
  assert_eq(pages[0], "第一页\npdf")
  assert_eq(pages[1], "第二页\npdf")
  assert_eq(pages[2], "第三页\npdf")
  assert_eq(
    @moonreader.read_pdf_text("testdata/sample.pdf"),
    "第一页\npdf\n第二页\npdf\n第三页\npdf",
  )
}

///|
test "detect_encoding 识别常见编码" {
  let gbk = Bytes::from_array([
    b'\xD6', b'\xD0', b'\xCE', b'\xC4', b'\xB1', b'\xE0', b'\xC2', b'\xEB',
  ])
  let utf8 = Bytes::from_array([
    b'\xE4', b'\xB8', b'\xAD', b'\xE6', b'\x96', b'\x87',
  ])
  let utf16le = Bytes::from_array([
    b'\xFF', b'\xFE', b'\x2D', b'\x4E', b'\x87', b'\x65',
  ])
  let utf16be = Bytes::from_array([
    b'\xFE', b'\xFF', b'\x4E', b'\x2D', b'\x65', b'\x87',
  ])
  assert_eq(@moonreader.detect_encoding(gbk), @moonreader.Encoding::Gbk)
  assert_eq(@moonreader.detect_encoding(utf8), @moonreader.Encoding::Utf8)
  assert_eq(@moonreader.detect_encoding(utf16le), @moonreader.Encoding::Utf16Le)
  assert_eq(@moonreader.detect_encoding(utf16be), @moonreader.Encoding::Utf16Be)
}

///|
test "decode_auto 解码 GBK 与 UTF-8 中文" {
  let gbk = Bytes::from_array([
    b'\xD6', b'\xD0', b'\xCE', b'\xC4', b'\xB1', b'\xE0', b'\xC2', b'\xEB',
  ])
  assert_eq(@moonreader.decode_auto(gbk), "中文编码")
  let utf8 = Bytes::from_array([
    b'\xE4', b'\xB8', b'\xAD', b'\xE6', b'\x96', b'\x87',
  ])
  assert_eq(@moonreader.decode_auto(utf8), "中文")
}

///|
test "decode_auto 解码 UTF-16LE 带 BOM" {
  let utf16le = Bytes::from_array([
    b'\xFF', b'\xFE', b'\x2D', b'\x4E', b'\x87', b'\x65',
  ])
  assert_eq(@moonreader.decode_auto(utf16le), "中文")
}

///|
test "decode_big5 显式解码繁体中文" {
  let big5 = Bytes::from_array([
    b'\xC1', b'\x63', b'\xC5', b'\xE9', b'\xA4', b'\xA4', b'\xA4', b'\xE5',
  ])
  assert_eq(@moonreader.decode_big5(big5), "繁體中文")
}

///|
test "read_txt 自动检测并解码 GBK 编码文件" {
  assert_eq(
    @moonreader.read_txt("testdata/encoding_gbk.txt"),
    "中文编码\n明月几时有",
  )
}

///|
test "read_txt 显式指定编码解码 Big5 文件" {
  assert_eq(
    @moonreader.read_txt(
      "testdata/encoding_big5.txt",
      encoding=Some(@moonreader.Encoding::Big5),
    ),
    "繁體中文",
  )
}

///|
test "read_txt 显式指定 GBK 解码与自动检测一致" {
  assert_eq(
    @moonreader.read_txt(
      "testdata/encoding_gbk.txt",
      encoding=Some(@moonreader.Encoding::Gbk),
    ),
    "中文编码\n明月几时有",
  )
}

///|
test "parse_encoding 解析编码名称" {
  assert_eq(@moonreader.parse_encoding("GBK"), Some(@moonreader.Encoding::Gbk))
  assert_eq(
    @moonreader.parse_encoding("big5"),
    Some(@moonreader.Encoding::Big5),
  )
  assert_eq(
    @moonreader.parse_encoding("utf-8"),
    Some(@moonreader.Encoding::Utf8),
  )
  assert_eq(
    @moonreader.parse_encoding("utf-16"),
    Some(@moonreader.Encoding::Utf16Le),
  )
  assert_eq(@moonreader.parse_encoding("no-such-enc"), None)
}

///|
test "read_tar_text 自动检测 GBK 内层文件" {
  assert_eq(
    @moonreader.read_tar_text("testdata/gbk_inner.tar", "gbk.txt"),
    "中文编码",
  )
}

///|
test "read_zip_text 自动检测 GBK 内层文件" {
  assert_eq(
    @moonreader.read_zip_text("testdata/gbk_inner.zip", "gbk.txt"),
    "中文编码",
  )
}

///|
test "read_csv_by_line 自动检测 GBK 编码" {
  let rows = @moonreader.read_csv_by_line("testdata/encoding_gbk.csv")
  assert_eq(rows.length(), 3)
  assert_eq(rows[0][0], "姓名")
  assert_eq(rows[0][1], "城市")
  assert_eq(rows[1][0], "张三")
  assert_eq(rows[1][1], "北京")
  assert_eq(rows[2][0], "李四")
  assert_eq(rows[2][1], "上海")
}

///|
test "read_xml 自动检测 GBK 编码" {
  let root = @moonreader.read_xml("testdata/encoding_gbk.xml")
  assert_eq(root.name, "书名")
  assert_eq(root.attr("作者"), Some("张三"))
  assert_eq(root.text(), "内容")
}

///|
test "read_json 自动检测 GBK 编码" {
  assert_eq(
    @moonreader.read_json("testdata/encoding_gbk.json").stringify(),
    "{\"姓名\":\"张三\"}",
  )
}

///|
test "read_csv_by_line 显式指定 GBK 解码" {
  let rows = @moonreader.read_csv_by_line(
    "testdata/encoding_gbk.csv",
    encoding=Some(@moonreader.Encoding::Gbk),
  )
  assert_eq(rows.length(), 3)
  assert_eq(rows[0][0], "姓名")
  assert_eq(rows[1][0], "张三")
  assert_eq(rows[2][0], "李四")
}

///|
test "encode 编码 GBK 字节正确" {
  let bytes = @moonreader.encode("中文", @moonreader.Encoding::Gbk)
  assert_eq(bytes, Bytes::from_array([b'\xD6', b'\xD0', b'\xCE', b'\xC4']))
}

///|
test "encode 编码 UTF-8 与解码往返" {
  let utf8 = @moonreader.encode("中文编码", @moonreader.Encoding::Utf8)
  assert_eq(
    @moonreader.decode(utf8, @moonreader.Encoding::Utf8),
    "中文编码",
  )
}

///|
test "encode 编码 UTF-16LE 带 BOM" {
  let b = @moonreader.encode("中文", @moonreader.Encoding::Utf16Le, bom=true)
  assert_eq(
    b,
    Bytes::from_array([b'\xFF', b'\xFE', b'\x2D', b'\x4E', b'\x87', b'\x65']),
  )
}

///|
test "encode 编码 Big5 与解码往返" {
  let b = @moonreader.encode("繁體中文", @moonreader.Encoding::Big5)
  assert_eq(@moonreader.decode(b, @moonreader.Encoding::Big5), "繁體中文")
}

///|
test "convert UTF-8 转 GBK 再转回" {
  let utf8 = @moonreader.encode("中文编码", @moonreader.Encoding::Utf8)
  let gbk = @moonreader.convert(
    utf8,
    @moonreader.Encoding::Utf8,
    @moonreader.Encoding::Gbk,
  )
  assert_eq(
    gbk,
    Bytes::from_array([
      b'\xD6', b'\xD0', b'\xCE', b'\xC4', b'\xB1', b'\xE0', b'\xC2', b'\xEB',
    ]),
  )
  let back = @moonreader.convert(
    gbk,
    @moonreader.Encoding::Gbk,
    @moonreader.Encoding::Utf8,
  )
  assert_eq(
    @moonreader.decode(back, @moonreader.Encoding::Utf8),
    "中文编码",
  )
}

///|
test "convert Latin-1 转 UTF-8" {
  let latin1 = Bytes::from_array([b'\x48', b'\xE9', b'\x6C', b'\x6C', b'\x6F'])
  let utf8 = @moonreader.convert(
    latin1,
    @moonreader.Encoding::Latin1,
    @moonreader.Encoding::Utf8,
  )
  assert_eq(@moonreader.decode(utf8, @moonreader.Encoding::Utf8), "Héllo")
}
