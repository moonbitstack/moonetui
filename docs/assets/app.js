// moonetui documentation — theme, routing, tiny interactions. No frameworks.

(function () {
  "use strict";

  var root = document.documentElement;

  // Theme: dark first, choice kept locally.
  var saved = null;
  try {
    saved = localStorage.getItem("moonetui-theme");
  } catch (e) {
    saved = null;
  }
  if (saved === "light") {
    root.setAttribute("data-theme", "light");
  }

  var toggles = Array.prototype.slice.call(
    document.querySelectorAll(".theme-toggle")
  );
  toggles.forEach(function (toggle) {
    toggle.addEventListener("click", function () {
      var next = root.getAttribute("data-theme") === "light" ? "dark" : "light";
      if (next === "light") {
        root.setAttribute("data-theme", "light");
      } else {
        root.removeAttribute("data-theme");
      }
      try {
        localStorage.setItem("moonetui-theme", next);
      } catch (e) {
        /* choice is a nicety, not a need */
      }
    });
  });

  // Hash routing: #/started shows the section with that id.
  var links = Array.prototype.slice.call(
    document.querySelectorAll(".side nav a")
  );
  var pages = Array.prototype.slice.call(document.querySelectorAll(".page"));
  var crumbs = Array.prototype.slice.call(
    document.querySelectorAll(".crumb-here")
  );

  function show(hash) {
    var id = (hash || "#/").replace("#/", "");
    var target = id === "" ? "home" : id;
    var found = false;
    pages.forEach(function (page) {
      var on = page.id === "page-" + target;
      page.classList.toggle("show", on);
      if (on) {
        found = true;
      }
    });
    if (!found) {
      pages.forEach(function (page) {
        page.classList.toggle("show", page.id === "page-home");
      });
      target = "home";
    }
    links.forEach(function (link) {
      link.classList.toggle("active", link.getAttribute("href") === "#/" + target);
    });
    if (crumbs.length > 0) {
      var label =
        target === "home" ? "home" : target.replace(/-/g, " ");
      crumbs.forEach(function (crumb) {
        crumb.textContent = label;
      });
    }
    window.scrollTo(0, 0);
  }

  window.addEventListener("hashchange", function () {
    show(location.hash);
  });
  show(location.hash);

  // A quiet typing effect for the hero prompt line.
  var typed = document.getElementById("typed");
  if (typed) {
    var text = "moon run --target native examples/tui";
    var at = 0;
    var timer = setInterval(function () {
      at += 1;
      typed.textContent = text.slice(0, at);
      if (at >= text.length) {
        clearInterval(timer);
      }
    }, 55);
  }
})();
