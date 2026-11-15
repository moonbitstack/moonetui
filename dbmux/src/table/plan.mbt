// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a save is about to run, and how many rows of each kind. The preview
/// shows these statements before anything is sent; the save sends exactly
/// them, in one transaction.
pub(all) struct SavePlan {
  statements : Array[String]
  updates : Int32
  inserts : Int32
  deletes : Int32
}

///|
pub fn SavePlan::is_empty(self : SavePlan) -> Bool {
  self.statements.length() == 0
}

///|
/// `3 updates, 1 insert, 1 delete` for the confirmation line.
pub fn SavePlan::summary(self : SavePlan) -> String {
  let parts : Array[String] = []
  if self.updates == 1 {
    parts.push("1 update")
  } else if self.updates > 1 {
    parts.push(self.updates.to_string() + " updates")
  }
  if self.inserts == 1 {
    parts.push("1 insert")
  } else if self.inserts > 1 {
    parts.push(self.inserts.to_string() + " inserts")
  }
  if self.deletes == 1 {
    parts.push("1 delete")
  } else if self.deletes > 1 {
    parts.push(self.deletes.to_string() + " deletes")
  }
  parts.join(", ")
}

///|
/// A save that cannot be written down, said plainly.
pub(all) suberror Refused {
  Refused(text~ : String)
}

///|
/// The statements a save runs. Every UPDATE and DELETE carries the values the
/// row had when it was read, so a row someone else changed in the meantime
/// matches nothing, and the save rolls back.
pub fn plan(grid : Grid, dialect : @sqlkit.Dialect) -> SavePlan raise Refused {
  let table = dialect.qualify(grid.page.schema, grid.page.table)
  let statements : Array[String] = []
  let mut updates = 0
  for row in 0..<grid.page.rows.length() {
    if grid.is_marked(row) {
      continue
    }
    let changed : Array[(String, String?)] = []
    for column in grid.page.columns {
      if grid.changes.contains(change_key(row, column)) {
        changed.push((column, grid.cell(row, column).value()))
      }
    }
    if changed.length() == 0 {
      continue
    }
    let predicates = grid.predicates(row, dialect)
    if predicates.length() == 0 {
      raise Refused(text="a table with no columns cannot be saved")
    }
    statements.push(@sqlkit.update_sql(dialect, table, changed, predicates))
    updates = updates + 1
  }
  let mut inserts = 0
  for at in 0..<grid.added.length() {
    let row = grid.page.rows.length() + at
    let values : Array[(String, String?)] = []
    for column in grid.page.columns {
      values.push((column, grid.cell(row, column).value()))
    }
    statements.push(@sqlkit.insert_sql(dialect, table, values))
    inserts = inserts + 1
  }
  let mut deletes = 0
  for row in grid.deleted {
    if row >= grid.page.rows.length() {
      continue
    }
    let predicates = grid.predicates(row, dialect)
    if predicates.length() == 0 {
      raise Refused(text="a table with no columns cannot be saved")
    }
    statements.push(@sqlkit.delete_sql(table, predicates))
    deletes = deletes + 1
  }
  { statements, updates, inserts, deletes, }
}

///|
/// What identifies a row in a WHERE: its primary key when the catalog named
/// one, and every column's old value when it did not. Without a key, a table
/// of two identical rows is a table where one statement matches two rows, and
/// the save's row-count check is what stops it.
pub fn Grid::predicates(
  self : Grid,
  row : Int32,
  dialect : @sqlkit.Dialect,
) -> Array[String] {
  let out : Array[String] = []
  if self.page.keys.length() > 0 {
    for key in self.page.keys {
      out.push(@sqlkit.equal_sql(dialect, key, self.original(row, key).value()))
    }
    out
  } else {
    for column in self.page.columns {
      out.push(
        @sqlkit.equal_sql(dialect, column, self.original(row, column).value()),
      )
    }
    out
  }
}
