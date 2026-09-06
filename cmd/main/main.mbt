fn main {
  let args = @env.args()
  // args[0] 是程序名，args[1] 起才是传入的参数
  if args.length() < 2 {
    print_usage()
    return
  }
  let path = args[1]
  try {
    if path.has_suffix(".csv".view()) {
      let rows = @moonreader.read_csv_by_line(path)
      println("CSV 行数: " + rows.length().to_string())
      for row in rows {
        println(join(row, " | "))
      }
    } else if path.has_suffix(".jsonl".view()) {
      let js = @moonreader.read_jsonl_by_line(path)
      println("JSONL 行数: " + js.length().to_string())
      for j in js {
        println(j.stringify())
      }
    } else if path.has_suffix(".json".view()) {
      let j = @moonreader.read_json_dynamic(path)
      println("JSON 解析成功:")
      println(j.stringify(indent=2))
    } else if path.has_suffix(".tar".view()) {
      if args.length() >= 3 {
        // 读取包内指定文件的内容
        let inner = args[2]
        println(@moonreader.read_tar_text(path, inner))
      } else {
        // 列出包内文件名，并逐个 dump 内容
        let names = @moonreader.list_tar_filenames(path)
        println("TAR 文件数: " + names.length().to_string())
        for name in names {
          println("  " + name)
        }
        for name in names {
          let content = @moonreader.read_tar_text(path, name)
          println("--- " + name + " ---")
          println(content)
        }
      }
    } else {
      // 未知扩展名，默认按 TXT 按行读取
      let lines = @moonreader.read_txt_by_line(path)
      println("TXT 行数: " + lines.length().to_string())
      for line in lines {
        println(line)
      }
    }
  } catch {
    _ => println("读取失败: " + path)
  }
}

fn print_usage() -> Unit {
  println("MoonReader — MoonBit 文件读取演示")
  println("")
  println("用法: moon run cmd/main -- <文件路径> [包内文件名]")
  println("  根据扩展名自动识别格式:")
  println("    .txt   → 按行读取文本")
  println("    .csv   → 按行读取 CSV")
  println("    .json  → 解析 JSON")
  println("    .jsonl → 按行解析 JSONL")
  println("    .tar   → 列出压缩包内文件名")
  println("    .tar <包内文件名> → 读取包内指定文件内容")
}

/// 把字符串数组用分隔符拼成一个字符串
fn join(arr : Array[String], sep : String) -> String {
  let mut s = ""
  let mut first = true
  for x in arr {
    if first {
      s = x
      first = false
    } else {
      s = s + sep + x
    }
  }
  s
}
