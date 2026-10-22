// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a rule attaches to. Every part is optional, and a rule matches a node
/// when every part it names matches:
///
/// - `name` — the node's own name, the way a type selector works in CSS.
/// - `id` — one node, the way an id selector works.
/// - `classes` — every class named must be on the node.
/// - `focus` — the node holds keyboard focus, the `:focus` pseudo-class.
///
/// A selector that names nothing matches every node, which is what a rule that
/// styles the whole application looks like.
pub(all) struct Sel {
  name : String
  id : Int32
  classes : Array[String]
  focus : Bool
} derive(Eq, Debug)

///|
pub extend Sel with Debug::{to_repr}

///|
pub extend Sel with Eq::{not_equal, equal}

///|
/// Build a selector. An id of -1 means "any".
pub fn Sel::new(
  name~ : String = "",
  id~ : Int32 = -1,
  classes~ : Array[String] = [],
  focus~ : Bool = false,
) -> Sel {
  { name, id, classes, focus, }
}

///|
/// True when a node with this name, this id, these classes, and this focus
/// state is what the selector describes.
pub fn Sel::matches(
  self : Sel,
  name : String,
  id : Int32,
  classes : Array[String],
  focused : Bool,
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
  for wanted in self.classes {
    let mut found = false
    for own in classes {
      if own == wanted {
        found = true
        break
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
/// How much this selector counts when two rules both match: an id outweighs
/// any number of classes, a class outweighs a name, and — because the totals
/// are compared before the order the rules were written in — two rules of the
/// same weight are settled by which was written later.
pub fn Sel::specificity(self : Sel) -> Int32 {
  let id = if self.id >= 0 { 100 } else { 0 }
  let class = self.classes.length() * 10 + (if self.focus { 10 } else { 0 })
  let named = if self.name.length() > 0 { 1 } else { 0 }
  id + class + named
}

///|
/// One rule: the styles a selector attaches to.
pub(all) struct Rule {
  sel : Sel
  styles : Styles
} derive(Eq, Debug)

///|
pub extend Rule with Debug::{to_repr}

///|
pub extend Rule with Eq::{not_equal, equal}

///|
/// A rule over a selector.
pub fn Rule::new(sel : Sel, styles : Styles) -> Rule {
  { sel, styles, }
}

///|
/// The rules an application is styled by, in the order they were written.
pub(all) struct Stylesheet {
  rules : Array[Rule]
} derive(Eq, Debug)

///|
pub extend Stylesheet with Debug::{to_repr}

///|
pub extend Stylesheet with Eq::{not_equal, equal}

///|
/// A stylesheet with no rules: the application is styled by its base style
/// and nothing else.
pub fn Stylesheet::new() -> Stylesheet {
  { rules: [], }
}

///|
/// Add a rule. Rules written later sit on top of rules written earlier with
/// the same specificity, exactly as lines of CSS do.
pub fn Stylesheet::add(self : Stylesheet, sel : Sel, styles : Styles) -> Unit {
  self.rules.push(Rule::new(sel, styles))
}

///|
/// True when no rule has been written.
pub fn Stylesheet::is_empty(self : Stylesheet) -> Bool {
  self.rules.length() == 0
}

///|
/// The rules in the order they were written, for tests that want to see them.
pub fn Stylesheet::list(self : Stylesheet) -> Array[Rule] {
  self.rules
}

///|
/// The styles the cascade hands this node: every matching rule merged in
/// ascending order of specificity, so the most specific rule is merged last
/// and wins. This is half the cascade; the caller layers the node's inline
/// styles over the result and the container's text style underneath.
pub fn Stylesheet::pick(
  self : Stylesheet,
  name : String,
  id : Int32,
  classes : Array[String],
  focused : Bool,
) -> Styles {
  // Matching rules in ascending order of (specificity, position): the rule
  // merged last is the most specific one, or among equals the one written
  // later — so the fold below ends with that rule on top.
  let matching : Array[(Int32, Int32, Styles)] = []
  for i in 0..<self.rules.length() {
    let rule = self.rules[i]
    if !rule.sel.matches(name, id, classes, focused) {
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
