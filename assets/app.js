// Phase 2: render the full buffer as Markdown via markdown-it (GFM tables +
// strikethrough are built into its default preset) plus the task-lists
// plugin for GitHub-style checkboxes. Phase 3: live re-render on buffer
// change. Phase 4: syntax-highlight fenced code blocks via highlight.js —
// a fence whose language highlight.js doesn't recognize (e.g. a
// ```mermaid block, since mermaid_fences = "plain" in v1) falls through to
// markdown-it's own default escaping, i.e. renders as plain code. Phase 5:
// scroll sync — every block-level token carries its source line as a
// data-line attribute; a "cursor" SSE event scrolls the nearest one into
// view. Phase 6: theme — data-color-mode drives github-markdown-css'
// light/dark styling; the hljs stylesheet's href is swapped between its
// light/dark data-attributes to match.
(function () {
  var payloadEl = document.getElementById("revelio-payload");
  var initial = { source: "", theme: "dark" };
  try {
    initial = JSON.parse(payloadEl.textContent);
  } catch (e) {
    console.error("revelio: could not parse initial payload", e);
  }

  var placeholderEl = document.getElementById("placeholder");
  var contentEl = document.getElementById("content");
  var hljsThemeEl = document.getElementById("revelio-hljs-theme");

  function applyTheme(theme) {
    document.documentElement.setAttribute("data-color-mode", theme);
    if (hljsThemeEl) {
      var href = theme === "light" ? hljsThemeEl.getAttribute("data-light-href") : hljsThemeEl.getAttribute("data-dark-href");
      if (href) {
        hljsThemeEl.setAttribute("href", href);
      }
    }
  }

  applyTheme(initial.theme);

  var md = window.markdownit({
    highlight: function (str, lang) {
      if (window.hljs && lang && window.hljs.getLanguage(lang)) {
        try {
          return window.hljs.highlight(str, { language: lang }).value;
        } catch (e) {
          console.warn("revelio: highlight.js failed for language " + lang, e);
        }
      }
      return ""; // markdown-it falls back to its own default escaping
    },
  });
  if (window.markdownitTaskLists) {
    md.use(window.markdownitTaskLists, { enabled: false });
  }

  // Stamp data-line="<source line>" on every block-level token so a later
  // "cursor" SSE event can find the rendered element nearest a given line.
  md.core.ruler.push("revelio-line-numbers", function (state) {
    state.tokens.forEach(function (token) {
      if (token.map) {
        token.attrSet("data-line", String(token.map[0]));
      }
    });
  });

  function render(source) {
    if (placeholderEl) {
      placeholderEl.remove();
      placeholderEl = null;
    }
    contentEl.innerHTML = md.render(source || "");
  }

  render(initial.source);

  // Scroll the rendered block nearest (at or before) the given source line
  // into view. "Nearest" means the largest data-line that does not exceed
  // the target — the block the cursor is actually inside, not the next one.
  function scrollToLine(line) {
    var candidates = contentEl.querySelectorAll("[data-line]");
    var best = null;
    var bestLine = -1;
    for (var i = 0; i < candidates.length; i++) {
      var el = candidates[i];
      var elLine = parseInt(el.getAttribute("data-line"), 10);
      if (elLine <= line && elLine > bestLine) {
        best = el;
        bestLine = elLine;
      }
    }
    if (best) {
      best.scrollIntoView({ block: "center", behavior: "smooth" });
    }
  }

  var events = new EventSource("/events");
  events.addEventListener("source", function (evt) {
    var data = JSON.parse(evt.data);
    render(data.source);
  });
  events.addEventListener("cursor", function (evt) {
    var data = JSON.parse(evt.data);
    scrollToLine(data.line);
  });
  events.addEventListener("theme", function (evt) {
    var data = JSON.parse(evt.data);
    applyTheme(data.theme);
  });
  events.onerror = function () {
    console.warn("revelio: SSE connection lost — the preview will stop updating live");
  };
})();
