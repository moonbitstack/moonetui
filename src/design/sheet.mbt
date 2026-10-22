// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Sel {
  name : String
  id : Int32
  classes : Array[String]
  focus : Bool
  hover : Bool
  disabled : Bool
} derive(Eq, Debug)

///|
pub extend Sel with Debug::{to_repr}

///|
pub extend Sel with Eq::{not_equal, equal}

///|
pub fn Sel::new(
  name~ : String = "",
  id~ : Int32 = -1,
  classes~ : Array[String] = [],
  focus~ : Bool = false,
  hover~ : Bool = false,
  disabled~ : Bool = false,
) -> Sel {
  { name, id, classes, focus, hover, disabled, }
}

///|
pub fn Sel::matches(
  self : Sel,
  name : String,
  id : Int32,
  classes : Array[String],
  focused : Bool,
  hovered : Bool,
  disabled : Bool,
) -> Bool {
  if self.name.length() > 0 && self.name != name {
    return false
  }
  if self.id >= 0 && self.id != id {
    return false
  }
  if self.focus && !focused {
    return false
  }
  if self.hover && !hovered {
    return false
  }
  if self.disabled && !disabled {
    return false
  }
  self.classes.iter().all(wanted => classes.contains(wanted))
}

///|
/// The CSS weight of the selector: ids, then classes and pseudo-classes, then
/// names, packed so that one number orders the same way the triple does.
pub fn Sel::specificity(self : Sel) -> Int32 {
  let ids = if self.id >= 0 { 1 } else { 0 }
  let states = [self.focus, self.hover, self.disabled].filter(on => on).length()
  let classes = self.classes.length() + states
  let names = if self.name.length() > 0 { 1 } else { 0 }
  ids * 1_000_000 + classes * 1_000 + names
}

///|
pub(all) struct Rule {
  sel : Sel
  styles : Styles
} derive(Eq, Debug)

///|
pub extend Rule with Debug::{to_repr}

///|
pub extend Rule with Eq::{not_equal, equal}

///|
pub fn Rule::new(sel : Sel, styles : Styles) -> Rule {
  { sel, styles, }
}

///|
pub(all) struct Stylesheet {
  rules : Array[Rule]
} derive(Eq, Debug)

///|
pub extend Stylesheet with Debug::{to_repr}

///|
pub extend Stylesheet with Eq::{not_equal, equal}

///|
pub fn Stylesheet::new() -> Stylesheet {
  { rules: [], }
}

///|
pub fn Stylesheet::add(self : Stylesheet, sel : Sel, styles : Styles) -> Unit {
  self.rules.push(Rule::new(sel, styles))
}

///|
pub fn Stylesheet::is_empty(self : Stylesheet) -> Bool {
  self.rules.length() == 0
}

///|
pub fn Stylesheet::list(self : Stylesheet) -> Array[Rule] {
  self.rules
}

///|
pub fn Stylesheet::pick(
  self : Stylesheet,
  name : String,
  id : Int32,
  classes : Array[String],
  focused : Bool,
  hovered~ : Bool = false,
  disabled~ : Bool = false,
) -> Styles {
  let matching : Array[(Int32, Int32, Styles)] = []
  for i in 0..<self.rules.length() {
    let rule = self.rules[i]
    if !rule.sel.matches(name, id, classes, focused, hovered, disabled) {
      continue
    }
    let spec = rule.sel.specificity()
    let mut at = matching.length()
    for j in 0..<matching.length() {
      let (other_spec, other_idx, _) = matching[j]
      if other_spec > spec || (other_spec == spec && other_idx > i) {
        at = j
        break
      }
    }
    matching.insert(at, (spec, i, rule.styles))
  }
  let mut out = empty
  for entry in matching {
    out = out.merge(entry.2)
  }
  out
}
