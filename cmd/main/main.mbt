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
  println("用法: main <文件路径>")
  println("  根据扩展名自动识别格式:")
  println("    .txt → 按行读取文本")
  println("    .csv → 按行读取 CSV")
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
