// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "CSV quotes only what has to be quoted" {
  let rows : Array[Array[@table.Cell]] = [
    [@table.Cell::of("plain"), @table.Cell::of("a,b")],
    [@table.Cell::of("say \"hi\""), @table.Cell::none()],
    [@table.Cell::of("two\nlines"), @table.Cell::of("")],
  ]
  assert_eq(
    @export.csv(["name", "note"], rows),
    "name,note\r\nplain,\"a,b\"\r\n\"say \"\"hi\"\"\",\r\n\"two\nlines\",\r\n",
  )
}

///|
test "JSON writes NULL as null and keeps the rest as text" {
  let rows : Array[Array[@table.Cell]] = [
    [@table.Cell::of("1"), @table.Cell::none()],
  ]
  let text = @export.json(["id", "note"], rows)
  assert_eq(text.contains("\"id\": \"1\""), true)
  assert_eq(text.contains("\"note\": null"), true)
}
