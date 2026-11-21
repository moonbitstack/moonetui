// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// Reading Markdown: the blocks a document is made of and the small readers that
// tell them apart — a heading, a rule, a list item, a table's separator row.

///|
priv enum MDFlow {
  MDHeading(Int32, String)
  MDParagraph(String)
  MDQuote(String)
  MDBullet(Int32, String)
  MDNumbered(Int32, Int32, String)
  MDCode(Array[String])
  MDRule
  MDTable(Array[Align], Array[String], Array[Array[String]])
}

///|
fn md_trim(line : String) -> String {
  let mut start = 0
  let end = line.length()
  while start < end && (line[start] == ' ' || line[start] == '\t') {
    start = start + 1
  }
  let mut stop = end
  while stop > start && (line[stop - 1] == ' ' || line[stop - 1] == '\t') {
    stop = stop - 1
  }
  line[start:stop].to_owned()
}

///|
fn md_spaces_of(line : String) -> Int32 {
  let mut count = 0
  let total = line.length()
  while count < total && line[count] == ' ' {
    count = count + 1
  }
  count
}

///|
fn md_starts_with(line : String, head : String) -> Bool {
  let span = head.length()
  if line.length() < span {
    return false
  }
  line[0:span].to_owned() == head
}

///|
fn md_heading(line : String) -> (Int32, String)? {
  let mut level = 0
  let total = line.length()
  while level < total && line[level] == '#' {
    level = level + 1
  }
  if level == 0 || level > 6 {
    return None
  }
  if level < total && line[level] != ' ' {
    return None
  }
  Some((level, md_trim(line[level:].to_owned())))
}

///|
fn md_hr(line : String) -> Bool {
  let total = line.length()
  if total < 3 {
    return false
  }
  let head = line[0]
  if head != '-' && head != '*' && head != '_' {
    return false
  }
  let mut at = 0
  while at < total {
    if line[at] != head {
      return false
    }
    at = at + 1
  }
  true
}

///|
fn md_split_row(line : String) -> Array[String] {
  let mut body = md_trim(line)
  if body.length() > 0 && body[0] == '|' {
    body = body[1:].to_owned()
  }
  if body.length() > 0 && body[body.length() - 1] == '|' {
    body = body[0:body.length() - 1].to_owned()
  }
  let cells : Array[String] = []
  let mut start = 0
  let total = body.length()
  let mut at = 0
  while at < total {
    if body[at] == '\\' && at + 1 < total && body[at + 1] == '|' {
      at = at + 2
    }
    if at < total && body[at] == '|' {
      cells.push(md_trim(body[start:at].to_owned()))
      start = at + 1
    }
    at = at + 1
  }
  cells.push(md_trim(body[start:].to_owned()))
  cells.map(c => c.replace_all(old="\\|", new="|"))
}

///|
fn md_sep_part(part : String) -> Bool {
  let total = part.length()
  if total == 0 {
    return false
  }
  let mut at = 0
  if part[at] == ':' {
    at = at + 1
  }
  let mut dashes = 0
  while at < total && part[at] == '-' {
    at = at + 1
    dashes = dashes + 1
  }
  if at < total && part[at] == ':' {
    at = at + 1
  }
  dashes > 0 && at == total
}

///|
fn md_align_of(part : String) -> Align {
  let total = part.length()
  let left = total > 0 && part[0] == ':'
  let right = total > 0 && part[total - 1] == ':'
  if left && right {
    return Centre
  }
  if right {
    return Right
  }
  Left
}

///|
fn md_table_sep(line : String) -> Array[Align]? {
  if !line.contains("|") {
    return None
  }
  let parts = md_split_row(line)
  let aligns : Array[Align] = []
  for part in parts {
    if !md_sep_part(part) {
      return None
    }
    aligns.push(md_align_of(part))
  }
  if aligns.length() == 0 {
    return None
  }
  Some(aligns)
}

///|
fn md_list(line : String) -> MDFlow? {
  let total = line.length()
  if total == 0 {
    return None
  }
  let head = line[0]
  if head == '-' || head == '+' || head == '*' {
    if total > 1 && line[1] == ' ' {
      return Some(MDBullet(0, md_trim(line[2:].to_owned())))
    }
    if total == 1 {
      return Some(MDBullet(0, ""))
    }
    return None
  }
  let mut digits = 0
  while digits < total && line[digits] >= '0' && line[digits] <= '9' {
    digits = digits + 1
  }
  if digits == 0 || digits + 1 >= total {
    return None
  }
  if line[digits] != '.' && line[digits] != ')' {
    return None
  }
  if line[digits + 1] != ' ' {
    return None
  }
  let number = md_number_of(line[0:digits].to_owned())
  Some(MDNumbered(0, number, md_trim(line[digits + 2:].to_owned())))
}

///|
fn md_parse(text : String) -> Array[MDFlow] {
  let blocks : Array[MDFlow] = []
  let lines = split_lines(text)
  let total = lines.length()
  let mut i = 0
  let mut para = ""
  let mut quote = ""
  while i < total {
    let raw = lines[i]
    let line = md_trim(raw)
    if line == "" {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      if quote != "" {
        blocks.push(MDQuote(quote))
        quote = ""
      }
      i = i + 1
      continue
    }
    if md_starts_with(line, "```") {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      if quote != "" {
        blocks.push(MDQuote(quote))
        quote = ""
      }
      i = i + 1
      let code : Array[String] = []
      while i < total && !md_starts_with(md_trim(lines[i]), "```") {
        code.push(lines[i])
        i = i + 1
      }
      blocks.push(MDCode(code))
      i = i + 1
      continue
    }
    match md_heading(line) {
      Some((level, head)) => {
        if para != "" {
          blocks.push(MDParagraph(para))
          para = ""
        }
        if quote != "" {
          blocks.push(MDQuote(quote))
          quote = ""
        }
        blocks.push(MDHeading(level, head))
        i = i + 1
        continue
      }
      None => ()
    }
    if md_hr(line) {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      if quote != "" {
        blocks.push(MDQuote(quote))
        quote = ""
      }
      blocks.push(MDRule)
      i = i + 1
      continue
    }
    if line.contains("|") &&
      i + 1 < total &&
      md_table_sep(md_trim(lines[i + 1])) is Some(_) {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      if quote != "" {
        blocks.push(MDQuote(quote))
        quote = ""
      }
      let head = md_split_row(line)
      let aligns = match md_table_sep(md_trim(lines[i + 1])) {
        Some(found) => found
        None => []
      }
      let rows : Array[Array[String]] = []
      i = i + 2
      while i < total {
        let body = md_trim(lines[i])
        if body == "" || !body.contains("|") {
          break
        }
        rows.push(md_split_row(body))
        i = i + 1
      }
      blocks.push(MDTable(aligns, head, rows))
      continue
    }
    if line[0] == '>' {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      let inner = md_trim(line[1:].to_owned())
      if quote == "" {
        quote = inner
      } else {
        quote = quote + " " + inner
      }
      i = i + 1
      continue
    }
    match md_list(line) {
      Some(MDBullet(_, item)) => {
        if para != "" {
          blocks.push(MDParagraph(para))
          para = ""
        }
        if quote != "" {
          blocks.push(MDQuote(quote))
          quote = ""
        }
        let depth = md_spaces_of(raw) / 2
        blocks.push(MDBullet(depth, item))
        i = i + 1
        continue
      }
      Some(MDNumbered(_, number, item)) => {
        if para != "" {
          blocks.push(MDParagraph(para))
          para = ""
        }
        if quote != "" {
          blocks.push(MDQuote(quote))
          quote = ""
        }
        let depth = md_spaces_of(raw) / 2
        blocks.push(MDNumbered(depth, number, item))
        i = i + 1
        continue
      }
      _ => ()
    }
    if quote != "" {
      // A paragraph after a quote closes the quote first.
      blocks.push(MDQuote(quote))
      quote = ""
    }
    if para == "" {
      para = line
    } else {
      para = para + " " + line
    }
    i = i + 1
  }
  if para != "" {
    blocks.push(MDParagraph(para))
  }
  if quote != "" {
    blocks.push(MDQuote(quote))
  }
  blocks
}

///|
fn md_number_of(text : String) -> Int32 {
  let total = text.length()
  let mut value = 0
  let mut at = 0
  while at < total && text[at] >= '0' && text[at] <= '9' {
    value = value * 10 + text[at].to_int() - 48
    at = at + 1
  }
  value
}

///|
fn md_index_of(text : String, needle : String, from : Int32) -> Int32 {
  let span = needle.length()
  let total = text.length()
  let mut at = if from < 0 { 0 } else { from }
  while at + span <= total {
    if text[at:at + span].to_owned() == needle {
      return at
    }
    at = at + 1
  }
  -1
}

///|
fn md_link_scan(text : String, from : Int32) -> (Int32, Int32)? {
  // (where `](` starts, where the matching `)` is)
  let open = md_index_of(text, "](", from)
  if open < 0 {
    return None
  }
  let end = md_index_of(text, ")", open + 2)
  if end < 0 {
    return None
  }
  Some((open, end))
}
