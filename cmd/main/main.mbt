///|
fn main {
  let args = @env.args()
  // args[0] 是程序名，args[1] 起才是传入的参数
  if args.length() < 2 {
    print_usage()
    return
  }
  let path = args[1]
  try {
    match @moonreader.detect_format(path) {
      @moonreader.FileFormat::Zip => print_zip(path, args)
      @moonreader.FileFormat::Tar => print_tar(path, args)
      _ =>
        // 非 tar 格式统一走 read() 自动分派
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
/// 打印 zip 包内容：指定包内文件则读取其内容，否则列出并逐个 dump
fn print_zip(
  path : String,
  args : Array[String],
) -> Unit raise @moonreader.ReaderError {
  if args.length() >= 3 {
    let inner = args[2]
    println(@moonreader.read_zip_text(path, inner))
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
    println(@moonreader.read_tar_text(path, inner))
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
fn print_usage() -> Unit {
  println("MoonReader — MoonBit 文件读取演示")
  println("")
  println("用法: moon run cmd/main -- <文件路径> [包内文件名]")
  println("  根据扩展名自动识别格式:")
  println("    .txt   → 按行读取文本")
  println("    .csv   → 按行读取 CSV")
  println("    .json  → 解析 JSON")
  println("    .jsonl → 按行解析 JSONL")
  println("    .xml   → 解析 XML")
  println("    .md    → 解析 Markdown")
  println("    .zip   → 列出压缩包内文件名")
  println("    .zip <包内文件名> → 读取包内指定文件内容")
  println("    .tar   → 列出压缩包内文件名")
  println("    .tar <包内文件名> → 读取包内指定文件内容")
  println("    .docx  → 读取 Word 文档文本")
  println("    .xlsx  → 读取 Excel 表格（行列）")
  println("    .pptx  → 读取 PPT 每页文本")
  println("    .pdf   → 读取 PDF 每页文本")
}
