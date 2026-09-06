fn main {
  let args = @env.args()
  // args[0] 是程序名，args[1] 起才是传入的参数
  if args.length() < 2 {
    print_usage()
    return
  }
  let path = args[1]
  try {
    // 当前阶段只发布 TXT 读取
    let lines = @moonreader.read_txt_by_line(path)
    println("TXT 行数: " + lines.length().to_string())
    for line in lines {
      println(line)
    }
  } catch {
    _ => println("读取失败: " + path)
  }
}

fn print_usage() -> Unit {
  println("MoonReader — MoonBit 文件读取演示")
  println("")
  println("用法: main <文件路径>")
  println("  当前阶段支持 .txt 按行读取")
}
