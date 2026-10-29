
(function () {
  "use strict";

  var root = document.documentElement;

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

  // Loaded on first view, so a page never opened costs nothing.
  var filter = document.querySelector(".api-filter");
  if (filter) {
    var items = Array.prototype.slice.call(document.querySelectorAll(".api-item"));
    var pkgs = Array.prototype.slice.call(document.querySelectorAll(".api-pkg"));
    var count = document.querySelector(".api-count");
    var empty = document.querySelector(".api-empty");
    var total = count.getAttribute("data-total");
    filter.addEventListener("input", function () {
      var q = filter.value.trim().toLowerCase();
      var shown = 0;
      items.forEach(function (item) {
        var own = q === "" || item.getAttribute("data-q").indexOf(q) >= 0;
        var any = false;
        item.querySelectorAll(".api-method").forEach(function (m) {
          var on = own || m.getAttribute("data-q").indexOf(q) >= 0;
          m.hidden = !on;
          any = any || on;
        });
        item.hidden = !(own || any);
        if (!item.hidden) {
          shown += 1;
        }
      });
      pkgs.forEach(function (pkg) {
        pkg.hidden = !pkg.querySelector(".api-item:not([hidden])");
      });
      count.textContent = q === "" ? total + " entries" : shown + " matching";
      empty.hidden = shown > 0;
    });
    document.querySelectorAll(".api-index button").forEach(function (chip) {
      chip.addEventListener("click", function () {
        var target = document.getElementById(chip.getAttribute("data-pkg"));
        if (target) {
          target.scrollIntoView({ behavior: "smooth", block: "start" });
        }
      });
    });
  }

  var toolkit = null;
  function load() {
    if (!toolkit) {
      toolkit = import("./moonetui.js");
    }
    return toolkit;
  }

  globalThis.moonetuiReport = function (canvas, text) {
    var line = document.querySelector('.wmsg[data-for="' + canvas + '"]');
    if (line) {
      line.textContent = text;
    }
  };

  var canvases = document.querySelectorAll("canvas[data-demo], #gallery-home");
  if ("IntersectionObserver" in window) {
    var watch = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) {
          return;
        }
        var el = entry.target;
        watch.unobserve(el);
        load()
          .then(function (m) {
            if (el.dataset.demo) {
              m.mount(el.id, el.dataset.demo);
            } else {
              m.start(el.id);
            }
          })
          .catch(function () {
            el.parentElement.classList.add("offline");
          });
      });
    });
    canvases.forEach(function (c) {
      watch.observe(c);
    });
  }
})();
