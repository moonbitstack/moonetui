
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
