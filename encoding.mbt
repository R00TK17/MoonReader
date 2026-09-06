// ============================================================
// 文本编码自动检测与解码
//
// 支持：UTF-8 / UTF-16(LE/BE) / UTF-32(LE/BE) / GBK / Big5 / Latin-1
// 检测策略（按优先级）：
//   1. BOM 嗅探（UTF-8 / UTF-16LE/BE / UTF-32LE/BE）
//   2. UTF-32 无 BOM 的零字节模式（每 4 字节组 3 个 0x00）
//   3. UTF-16 无 BOM 的零字节模式（某一奇偶位大量 0x00）
//   4. 严格 UTF-8 校验
//   5. GBK / Big5 双字节启发式（GBK 独有尾字节 0x80–0xA0 优先判为 GBK）
//   6. Latin-1 兜底
//
// GBK/Big5 码表来自 Unicode 官方映射文件（CP936.TXT / CP950.TXT），
// 见 gbk_table.mbt / big5_table.mbt。码表按线性索引存储（UInt16 小端），
// 查找 O(1)。
// ============================================================

///|
/// 文本编码类型
pub(all) enum Encoding {
  Utf8
  Utf16Le
  Utf16Be
  Utf32Le
  Utf32Be
  Gbk
  Big5
  Latin1
} derive(Eq, @debug.Debug)

///|
/// 检测字节流的文本编码（启发式，面向文本文件）。
///
/// 无法确定时优先 UTF-8 → GBK → Latin-1，简体中文环境下默认判 GBK。
pub fn detect_encoding(bytes : Bytes) -> Encoding {
  let arr = bytes.to_array()
  let n = arr.length()

  // 1. BOM 嗅探
  if n >= 4 &&
    arr[0] == b'\xFF' &&
    arr[1] == b'\xFE' &&
    arr[2] == b'\x00' &&
    arr[3] == b'\x00' {
    return Encoding::Utf32Le
  }
  if n >= 4 &&
    arr[0] == b'\x00' &&
    arr[1] == b'\x00' &&
    arr[2] == b'\xFE' &&
    arr[3] == b'\xFF' {
    return Encoding::Utf32Be
  }
  if n >= 2 && arr[0] == b'\xFF' && arr[1] == b'\xFE' {
    return Encoding::Utf16Le
  }
  if n >= 2 && arr[0] == b'\xFE' && arr[1] == b'\xFF' {
    return Encoding::Utf16Be
  }
  if n >= 3 && arr[0] == b'\xEF' && arr[1] == b'\xBB' && arr[2] == b'\xBF' {
    return Encoding::Utf8
  }

  // 2. UTF-32 无 BOM：每 4 字节组中 3 个 0x00
  let u32 = utf32_endian(arr)
  if u32 == 0 {
    return Encoding::Utf32Le
  }
  if u32 == 1 {
    return Encoding::Utf32Be
  }

  // 3. UTF-16 无 BOM：某一奇偶位大量 0x00
  let u16 = utf16_endian(arr)
  if u16 == 0 {
    return Encoding::Utf16Le
  }
  if u16 == 1 {
    return Encoding::Utf16Be
  }

  // 4. 严格 UTF-8 校验
  if is_valid_utf8(arr) {
    return Encoding::Utf8
  }

  // 5. GBK / Big5 双字节启发式
  let (gbk_only, gbk_pairs, stray) = classify_dbc(arr)
  if gbk_only > 0 || gbk_pairs > stray {
    return Encoding::Gbk
  }

  // 6. 其余高位字节 → Latin-1 兜底
  Encoding::Latin1
}

///|
/// 按指定编码解码为字符串（损坏字节替换为 U+FFFD）
pub fn decode(bytes : Bytes, encoding : Encoding) -> String {
  match encoding {
    Encoding::Utf8 => @utf8.decode_lossy(strip_utf8_bom(bytes))
    Encoding::Utf16Le =>
      @utf16.decode_lossy(
        bytes,
        ignore_bom=true,
        endianness=@utf16.Endian::Little,
      )
    Encoding::Utf16Be =>
      @utf16.decode_lossy(bytes, ignore_bom=true, endianness=@utf16.Endian::Big)
    Encoding::Utf32Le => utf32_decode(bytes, false)
    Encoding::Utf32Be => utf32_decode(bytes, true)
    Encoding::Gbk => gbk_decode(bytes)
    Encoding::Big5 => big5_decode(bytes)
    Encoding::Latin1 => latin1_decode(bytes)
  }
}

///|
/// 自动检测编码并解码（= decode(bytes, detect_encoding(bytes))）
pub fn decode_auto(bytes : Bytes) -> String {
  decode(bytes, detect_encoding(bytes))
}

///|
/// 显式按 GBK（简体中文）解码。自动检测对双字节文本默认即判 GBK。
pub fn decode_gbk(bytes : Bytes) -> String {
  decode(bytes, Encoding::Gbk)
}

///|
/// 显式按 Big5（繁体中文）解码。
/// GBK 与 Big5 在字节层面无法可靠区分，自动检测默认判 GBK，
/// 繁体文本需显式调用本函数。
pub fn decode_big5(bytes : Bytes) -> String {
  decode(bytes, Encoding::Big5)
}

///|
/// 解析编码名称为 Encoding（不区分大小写），支持常见别名。
/// 无法识别时返回 None，调用方可回退到自动检测。
pub fn parse_encoding(name : String) -> Encoding? {
  let n = name.to_lower()
  if n == "utf-8" || n == "utf8" {
    Some(Encoding::Utf8)
  } else if n == "utf-16le" ||
    n == "utf16le" ||
    n == "utf-16" ||
    n == "utf16" ||
    n == "unicode" {
    Some(Encoding::Utf16Le)
  } else if n == "utf-16be" || n == "utf16be" {
    Some(Encoding::Utf16Be)
  } else if n == "utf-32le" || n == "utf32le" || n == "utf-32" || n == "utf32" {
    Some(Encoding::Utf32Le)
  } else if n == "utf-32be" || n == "utf32be" {
    Some(Encoding::Utf32Be)
  } else if n == "gbk" || n == "gb2312" || n == "cp936" || n == "gb18030" {
    Some(Encoding::Gbk)
  } else if n == "big5" || n == "cp950" {
    Some(Encoding::Big5)
  } else if n == "latin1" || n == "latin-1" || n == "iso-8859-1" {
    Some(Encoding::Latin1)
  } else {
    None
  }
}

// ---------------- 检测辅助 ----------------

///|
/// 无 BOM 的 UTF-16 端序判定：返回 0=LE、1=BE、-1=不像 UTF-16
fn utf16_endian(arr : Array[Byte]) -> Int {
  let n = arr.length()
  if n < 4 || n % 2 != 0 {
    return -1
  }
  let mut even_zero = 0
  let mut odd_zero = 0
  let mut i = 0
  while i < n {
    if arr[i].to_int() == 0 {
      even_zero = even_zero + 1
    }
    if arr[i + 1].to_int() == 0 {
      odd_zero = odd_zero + 1
    }
    i = i + 2
  }
  let pairs = n / 2
  // 高位字节 0x00 出现在奇数位 → 小端；偶数位 → 大端
  if odd_zero * 2 >= pairs && even_zero * 4 <= pairs {
    0
  } else if even_zero * 2 >= pairs && odd_zero * 4 <= pairs {
    1
  } else {
    -1
  }
}

///|
/// 无 BOM 的 UTF-32 端序判定：返回 0=LE、1=BE、-1=不像 UTF-32
fn utf32_endian(arr : Array[Byte]) -> Int {
  let n = arr.length()
  if n < 8 || n % 4 != 0 {
    return -1
  }
  let groups = n / 4
  let mut le = 0
  let mut be = 0
  let mut i = 0
  while i < n {
    let b0 = arr[i].to_int()
    let b1 = arr[i + 1].to_int()
    let b2 = arr[i + 2].to_int()
    let b3 = arr[i + 3].to_int()
    if b1 == 0 && b2 == 0 && b3 == 0 && b0 != 0 {
      le = le + 1
    }
    if b0 == 0 && b1 == 0 && b2 == 0 && b3 != 0 {
      be = be + 1
    }
    i = i + 4
  }
  if le * 2 >= groups && le > be {
    0
  } else if be * 2 >= groups && be > le {
    1
  } else {
    -1
  }
}

///|
/// 严格 UTF-8 校验：拒绝过长编码、代理区、非法前导字节
fn is_valid_utf8(arr : Array[Byte]) -> Bool {
  let n = arr.length()
  let mut i = 0
  while i < n {
    let b = arr[i].to_int()
    if b < 0x80 {
      i = i + 1
    } else if b >= 0xC2 && b <= 0xDF {
      if i + 1 >= n || arr[i + 1].to_int() < 0x80 || arr[i + 1].to_int() > 0xBF {
        return false
      }
      i = i + 2
    } else if b == 0xE0 {
      if i + 2 >= n ||
        arr[i + 1].to_int() < 0xA0 ||
        arr[i + 1].to_int() > 0xBF ||
        arr[i + 2].to_int() < 0x80 ||
        arr[i + 2].to_int() > 0xBF {
        return false
      }
      i = i + 3
    } else if (b >= 0xE1 && b <= 0xEC) || (b >= 0xEE && b <= 0xEF) {
      if i + 2 >= n ||
        arr[i + 1].to_int() < 0x80 ||
        arr[i + 1].to_int() > 0xBF ||
        arr[i + 2].to_int() < 0x80 ||
        arr[i + 2].to_int() > 0xBF {
        return false
      }
      i = i + 3
    } else if b == 0xED {
      if i + 2 >= n ||
        arr[i + 1].to_int() < 0x80 ||
        arr[i + 1].to_int() > 0x9F ||
        arr[i + 2].to_int() < 0x80 ||
        arr[i + 2].to_int() > 0xBF {
        return false
      }
      i = i + 3
    } else if b == 0xF0 {
      if i + 3 >= n ||
        arr[i + 1].to_int() < 0x90 ||
        arr[i + 1].to_int() > 0xBF ||
        arr[i + 2].to_int() < 0x80 ||
        arr[i + 2].to_int() > 0xBF ||
        arr[i + 3].to_int() < 0x80 ||
        arr[i + 3].to_int() > 0xBF {
        return false
      }
      i = i + 4
    } else if b >= 0xF1 && b <= 0xF3 {
      if i + 3 >= n ||
        arr[i + 1].to_int() < 0x80 ||
        arr[i + 1].to_int() > 0xBF ||
        arr[i + 2].to_int() < 0x80 ||
        arr[i + 2].to_int() > 0xBF ||
        arr[i + 3].to_int() < 0x80 ||
        arr[i + 3].to_int() > 0xBF {
        return false
      }
      i = i + 4
    } else if b == 0xF4 {
      if i + 3 >= n ||
        arr[i + 1].to_int() < 0x80 ||
        arr[i + 1].to_int() > 0x8F ||
        arr[i + 2].to_int() < 0x80 ||
        arr[i + 2].to_int() > 0x8F ||
        arr[i + 3].to_int() < 0x80 ||
        arr[i + 3].to_int() > 0xBF {
        return false
      }
      i = i + 4
    } else {
      // 0x80–0xC1、0xF5–0xFF 等非法前导
      return false
    }
  }
  true
}

///|
/// 统计双字节序列：(GBK 独有对, 合法 GBK/Big5 对, 孤立高位字节)
fn classify_dbc(arr : Array[Byte]) -> (Int, Int, Int) {
  let n = arr.length()
  let mut gbk_only = 0
  let mut gbk_pairs = 0
  let mut stray = 0
  let mut i = 0
  while i < n {
    let b = arr[i].to_int()
    if b < 0x80 {
      i = i + 1
    } else if b >= 0x81 && b <= 0xFE && i + 1 < n {
      let t = arr[i + 1].to_int()
      if t >= 0x40 && t <= 0xFE && t != 0x7F {
        gbk_pairs = gbk_pairs + 1
        // GBK 尾字节 0x80–0xA0 是 Big5 不具备的
        if t >= 0x80 && t <= 0xA0 {
          gbk_only = gbk_only + 1
        }
        i = i + 2
      } else {
        stray = stray + 1
        i = i + 1
      }
    } else {
      stray = stray + 1
      i = i + 1
    }
  }
  (gbk_only, gbk_pairs, stray)
}

// ---------------- 解码辅助 ----------------

///|
/// 剥离 UTF-8 BOM（EF BB BF）
fn strip_utf8_bom(bytes : Bytes) -> Bytes {
  let arr = bytes.to_array()
  if arr.length() >= 3 &&
    arr[0] == b'\xEF' &&
    arr[1] == b'\xBB' &&
    arr[2] == b'\xBF' {
    Bytes::from_array(slice_bytes(arr, 3, arr.length()))
  } else {
    bytes
  }
}

///|
/// UTF-32 解码（big=true 大端），剥离 BOM，代理区/越界替换为 U+FFFD
fn utf32_decode(bytes : Bytes, big : Bool) -> String {
  let arr = bytes.to_array()
  let n = arr.length()
  let chars : Array[Char] = []
  let mut i = 0
  if n >= 4 {
    let is_bom = if big {
      arr[0] == b'\x00' &&
      arr[1] == b'\x00' &&
      arr[2] == b'\xFE' &&
      arr[3] == b'\xFF'
    } else {
      arr[0] == b'\xFF' &&
      arr[1] == b'\xFE' &&
      arr[2] == b'\x00' &&
      arr[3] == b'\x00'
    }
    if is_bom {
      i = 4
    }
  }
  while i + 3 < n {
    let cp = if big {
      (arr[i].to_int() << 24) |
      (arr[i + 1].to_int() << 16) |
      (arr[i + 2].to_int() << 8) |
      arr[i + 3].to_int()
    } else {
      arr[i].to_int() |
      (arr[i + 1].to_int() << 8) |
      (arr[i + 2].to_int() << 16) |
      (arr[i + 3].to_int() << 24)
    }
    if cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
      chars.push('\u{FFFD}')
    } else {
      chars.push(cp.unsafe_to_char())
    }
    i = i + 4
  }
  String::from_array(chars)
}

///|
/// Latin-1（ISO-8859-1）解码：字节直接映射到码点
fn latin1_decode(bytes : Bytes) -> String {
  let arr = bytes.to_array()
  let chars : Array[Char] = []
  for b in arr {
    chars.push(b.to_int().unsafe_to_char())
  }
  String::from_array(chars)
}

///|
/// GBK 解码：ASCII 直通，双字节查表，非法序列替换为 U+FFFD
fn gbk_decode(bytes : Bytes) -> String {
  let arr = bytes.to_array()
  let n = arr.length()
  let chars : Array[Char] = []
  let mut i = 0
  while i < n {
    let b = arr[i].to_int()
    if b < 0x80 {
      chars.push(b.unsafe_to_char())
      i = i + 1
    } else if b >= 0x81 && b <= 0xFE && i + 1 < n {
      let t = arr[i + 1].to_int()
      if t >= 0x40 && t <= 0xFE && t != 0x7F {
        let slot = if t < 0x7F { t - 0x40 } else { t - 0x41 }
        let lin = (b - 0x81) * 190 + slot
        let uni = gbk_lookup(lin)
        if uni == 0 {
          chars.push('\u{FFFD}')
        } else {
          chars.push(uni.unsafe_to_char())
        }
        i = i + 2
      } else {
        chars.push('\u{FFFD}')
        i = i + 1
      }
    } else {
      chars.push('\u{FFFD}')
      i = i + 1
    }
  }
  String::from_array(chars)
}

///|
/// Big5 解码：ASCII 直通，双字节查表，非法序列替换为 U+FFFD
fn big5_decode(bytes : Bytes) -> String {
  let arr = bytes.to_array()
  let n = arr.length()
  let chars : Array[Char] = []
  let mut i = 0
  while i < n {
    let b = arr[i].to_int()
    if b < 0x80 {
      chars.push(b.unsafe_to_char())
      i = i + 1
    } else if b >= 0x81 && b <= 0xFE && i + 1 < n {
      let t = arr[i + 1].to_int()
      let valid = (t >= 0x40 && t <= 0x7E) || (t >= 0xA1 && t <= 0xFE)
      if valid {
        let slot = if t <= 0x7E { t - 0x40 } else { t - 0xA1 + 63 }
        let lin = (b - 0x81) * 157 + slot
        let uni = big5_lookup(lin)
        if uni == 0 {
          chars.push('\u{FFFD}')
        } else {
          chars.push(uni.unsafe_to_char())
        }
        i = i + 2
      } else {
        chars.push('\u{FFFD}')
        i = i + 1
      }
    } else {
      chars.push('\u{FFFD}')
      i = i + 1
    }
  }
  String::from_array(chars)
}

///|
/// GBK 码表查找：线性索引 → UInt16 小端读取
fn gbk_lookup(lin : Int) -> Int {
  let off = lin * 2
  let lo = gbk_decode_table[off].to_int()
  let hi = gbk_decode_table[off + 1].to_int()
  lo | (hi << 8)
}

///|
/// Big5 码表查找：线性索引 → UInt16 小端读取
fn big5_lookup(lin : Int) -> Int {
  let off = lin * 2
  let lo = big5_decode_table[off].to_int()
  let hi = big5_decode_table[off + 1].to_int()
  lo | (hi << 8)
}
