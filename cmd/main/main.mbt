///|
fn main {
  let args = @env.args()
  // args[0] 是程序名，args[1] 起才是传入的参数
  if args.length() < 2 {
    print_usage()
    return
  }
  if args[1] == "convert" {
    print_convert(args) catch {
      _ => println("转换失败")
    }
    return
  }
  let path = args[1]
  let fmt = @moonreader.detect_format(path)
  try {
    match fmt {
      @moonreader.FileFormat::Zip => print_zip(path, args)
      @moonreader.FileFormat::Tar => print_tar(path, args)
      @moonreader.FileFormat::Txt => print_txt(path, args)
      _ =>
        // 其余格式统一走 read() 自动分派
        match @moonreader.read(path) {
          Lines(lines) => {
            println("TXT 行数: " + lines.length().to_string())
            for line in lines {
              println(line)
            }
          }
          Table(rows) => {
            println("CSV 行数: " + rows.length().to_string())
            for row in rows {
              println(row.join(" | ".view()))
            }
          }
          JsonValue(j) => {
            println("JSON 解析成功:")
            println(j.stringify(indent=2))
          }
          JsonRows(js) => {
            println("JSONL 行数: " + js.length().to_string())
            for j in js {
              println(j.stringify())
            }
          }
          XmlDoc(root) => {
            println("XML 解析成功:")
            println(root.to_string())
          }
          MarkdownBlocks(blocks) => {
            println("Markdown 块数: " + blocks.length().to_string())
            for b in blocks {
              println(b.to_string())
            }
          }
          DocxText(text) => {
            println("DOCX 文本:")
            println(text)
          }
          ExcelSheets(sheets) => {
            println("XLSX 工作表数: " + sheets.length().to_string())
            for s in sheets {
              println("=== " + s.name + " ===")
              for row in s.rows {
                println(row.join(" | ".view()))
              }
            }
          }
          PptxSlides(slides) => {
            println("PPTX 页数: " + slides.length().to_string())
            let mut i = 1
            for s in slides {
              println("--- 第 " + i.to_string() + " 页 ---")
              println(s)
              i = i + 1
            }
          }
          PdfPages(pages) => {
            println("PDF 页数: " + pages.length().to_string())
            let mut i = 1
            for p in pages {
              println("--- 第 " + i.to_string() + " 页 ---")
              println(p)
              i = i + 1
            }
          }
          ZipFiles(names) =>
            // 正常流程已在上面单独处理 zip，这里仅兜底
            println("ZIP 文件数: " + names.length().to_string())
          TarFiles(names) =>
            // 正常流程已在上面单独处理 tar，这里仅兜底
            println("TAR 文件数: " + names.length().to_string())
        }
    }
  } catch {
    _ => println("读取失败: " + path)
  }
}

///|
/// 读取文本文件并逐行打印；可选第 2 个参数显式指定编码（如 gbk / big5）
fn print_txt(
  path : String,
  args : Array[String],
) -> Unit raise @moonreader.ReaderError {
  let enc = opt_encoding(args, 2)
  let lines = @moonreader.read_txt_by_line(path, encoding=enc)
  println("TXT 行数: " + lines.length().to_string())
  for line in lines {
    println(line)
  }
}

///|
/// 从参数列表读取可选编码名（下标 idx 处）；识别失败打印提示并返回 None
fn opt_encoding(args : Array[String], idx : Int) -> @moonreader.Encoding? {
  if args.length() <= idx {
    None
  } else {
    match @moonreader.parse_encoding(args[idx]) {
      Some(e) => Some(e)
      None => {
        println(
          "未知编码: " +
          args[idx] +
          "（支持 utf-8 / utf-16 / gbk / big5 / latin1）",
        )
        None
      }
    }
  }
}

///|
/// 打印 zip 包内容：指定包内文件则读取其内容，否则列出并逐个 dump
fn print_zip(
  path : String,
  args : Array[String],
) -> Unit raise @moonreader.ReaderError {
  if args.length() >= 3 {
    let inner = args[2]
    let enc = opt_encoding(args, 3)
    println(@moonreader.read_zip_text(path, inner, encoding=enc))
  } else {
    // 一次读盘，内存里列出并 dump 全部条目
    let entries = @moonreader.read_zip_entries(path)
    println("ZIP 文件数: " + entries.length().to_string())
    for e in entries {
      println("  " + e.name)
    }
    for e in entries {
      println("--- " + e.name + " ---")
      println(e.text())
    }
  }
}

///|
/// 打印 tar 包内容：指定包内文件则读取其内容，否则列出并逐个 dump
fn print_tar(
  path : String,
  args : Array[String],
) -> Unit raise @moonreader.ReaderError {
  if args.length() >= 3 {
    let inner = args[2]
    let enc = opt_encoding(args, 3)
    println(@moonreader.read_tar_text(path, inner, encoding=enc))
  } else {
    // 一次读盘，内存里列出并 dump 全部条目
    let entries = @moonreader.read_tar_entries(path)
    println("TAR 文件数: " + entries.length().to_string())
    for e in entries {
      println("  " + e.name)
    }
    for e in entries {
      println("--- " + e.name + " ---")
      println(e.text())
    }
  }
}

///|
/// 编码转换：convert <文件路径> <目标编码> [源编码] [输出路径]
/// 源编码缺省自动检测；输出路径缺省覆盖写回原文件。
fn print_convert(args : Array[String]) -> Unit raise @moonreader.ReaderError {
  // args: [程序名, "convert", 路径, 目标编码, (源编码), (输出路径)]
  if args.length() < 4 {
    println(
      "用法: convert <文件路径> <目标编码> [源编码] [输出路径]",
    )
    println(
      "  目标编码 / 源编码: utf-8 utf-16 utf-16le utf-16be gbk big5 latin1",
    )
    return
  }
  let path = args[2]
  let to = match @moonreader.parse_encoding(args[3]) {
    Some(e) => e
    None => {
      println("未知目标编码: " + args[3])
      return
    }
  }
  let bytes = @moonreader.read_file_to_bytes_utf8(path)
  // 源编码：显式指定则用之，否则自动检测
  let (from, src_desc) = if args.length() >= 5 {
    match @moonreader.parse_encoding(args[4]) {
      Some(e) => (e, args[4])
      None => {
        println("未知源编码: " + args[4])
        return
      }
    }
  } else {
    (@moonreader.detect_encoding(bytes), "自动检测")
  }
  let out = @moonreader.convert(bytes, from, to)
  let out_path = if args.length() >= 6 { args[5] } else { path }
  @moonreader.write_file_to_bytes_utf8(out_path, out)
  println("已转换: " + path + " (" + src_desc + " → " + args[3] + ")")
  println("输出: " + out_path + " (" + out.length().to_string() + " 字节)")
}

///|
fn print_usage() -> Unit {
  println("MoonReader — MoonBit 文件读取演示")
  println("")
  println(
    "用法: moon run cmd/main -- <文件路径> [包内文件名] [编码]",
  )
  println(
    "  编码转换: moon run cmd/main -- convert <文件路径> <目标编码> [源编码] [输出路径]",
  )
  println(
    "  根据扩展名自动识别格式；文本内容默认自动检测编码:",
  )
  println("    .txt               → 按行读取文本")
  println(
    "    .txt <编码>         → 按指定编码读取（如 gbk / big5 / utf-16）",
  )
  println("    .csv / .json / .jsonl / .xml / .md → 对应格式解析")
  println("    .zip / .tar        → 列出压缩包内文件名")
  println(
    "    .zip <包内文件名> [编码] → 读取包内指定文件内容",
  )
  println(
    "    .tar <包内文件名> [编码] → 读取包内指定文件内容",
  )
  println("    .docx  → 读取 Word 文档文本")
  println("    .xlsx  → 读取 Excel 表格（行列）")
  println("    .pptx  → 读取 PPT 每页文本")
  println("    .pdf   → 读取 PDF 每页文本")
}
