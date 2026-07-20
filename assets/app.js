// Phase 2: render the full buffer as Markdown via markdown-it (GFM tables +
// strikethrough are built into its default preset) plus the task-lists
// plugin for GitHub-style checkboxes. Phase 3: live re-render on buffer
// change. Phase 4: syntax-highlight fenced code blocks via highlight.js.
// Phase 5: scroll sync — every block-level token carries its source line as
// a data-line attribute; a "cursor" SSE event scrolls the nearest one into
// view. Phase 6: theme — data-color-mode drives github-markdown-css'
// light/dark styling; the hljs stylesheet's href is swapped between its
// light/dark data-attributes to match. Phase 7: export — an "export" SSE
// event triggers assembling a self-contained HTML file (all current
// stylesheets fetched and inlined, live-sync script omitted), either
// downloaded directly or POSTed back for a server-side save. Phase 9:
// mermaid_fences = "render" overrides markdown-it's fence renderer so a
// ```mermaid block becomes a real diagram (mermaid.js) instead of
// highlighted/plain code text — every other language is untouched.
(function () {
  var payloadEl = document.getElementById("revelio-payload");
  var initial = { source: "", theme: "dark", basename: "revelio", mermaid_fences: "plain" };
  try {
    initial = JSON.parse(payloadEl.textContent);
  } catch (e) {
    console.error("revelio: could not parse initial payload", e);
  }

  var placeholderEl = document.getElementById("placeholder");
  var contentEl = document.getElementById("content");
  var hljsThemeEl = document.getElementById("revelio-hljs-theme");
  var mermaidRenderMode = initial.mermaid_fences === "render";
  var lastSource = "";

  // mermaid bakes its theme into the rendered SVG itself, not CSS — a theme
  // change can't just restyle existing diagrams, it has to re-render them.
  function mermaidTheme(theme) {
    return theme === "light" ? "default" : "dark";
  }

  function initMermaid(theme) {
    if (!window.mermaid) {
      return;
    }
    window.mermaid.initialize({ startOnLoad: false, theme: mermaidTheme(theme), securityLevel: "strict" });
  }

  function renderMermaidDiagrams() {
    if (!mermaidRenderMode || !window.mermaid) {
      return;
    }
    try {
      window.mermaid.run({ querySelector: ".mermaid", suppressErrors: true });
    } catch (e) {
      console.warn("revelio: mermaid.run() failed", e);
    }
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute("data-color-mode", theme);
    if (hljsThemeEl) {
      var href = theme === "light" ? hljsThemeEl.getAttribute("data-light-href") : hljsThemeEl.getAttribute("data-dark-href");
      if (href) {
        hljsThemeEl.setAttribute("href", href);
      }
    }
    if (mermaidRenderMode) {
      initMermaid(theme);
      // Skip on the very first call (before the initial render() below has
      // ever run) — there's nothing rendered yet to re-render.
      if (lastSource) {
        render(lastSource);
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

  if (mermaidRenderMode) {
    var defaultFence =
      md.renderer.rules.fence ||
      function (tokens, idx, options, env, self) {
        return self.renderToken(tokens, idx, options);
      };

    md.renderer.rules.fence = function (tokens, idx, options, env, self) {
      var token = tokens[idx];
      var lang = (token.info || "").trim().split(/\s+/)[0];
      if (lang === "mermaid") {
        var dataLine = token.attrGet("data-line");
        var dataLineAttr = dataLine !== null ? ' data-line="' + dataLine + '"' : "";
        return '<div class="mermaid"' + dataLineAttr + ">" + md.utils.escapeHtml(token.content) + "</div>\n";
      }
      return defaultFence(tokens, idx, options, env, self);
    };
  }

  function render(source) {
    lastSource = source || "";
    if (placeholderEl) {
      placeholderEl.remove();
      placeholderEl = null;
    }
    contentEl.innerHTML = md.render(lastSource);
    renderMermaidDiagrams();
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

  // --- Export -----------------------------------------------------------
  // Fetch every currently-linked stylesheet (app.css, github-markdown-css,
  // the active hljs theme) and inline it, so the exported file needs no
  // network access or CDN scripts to look right when opened standalone.
  function buildExportHtml() {
    var theme = document.documentElement.getAttribute("data-color-mode") || "dark";
    var linkEls = document.querySelectorAll('link[rel="stylesheet"]');
    var fetches = [];
    linkEls.forEach(function (link) {
      fetches.push(
        fetch(link.href)
          .then(function (r) {
            return r.text();
          })
          .catch(function (e) {
            console.warn("revelio: failed to inline stylesheet " + link.href, e);
            return "";
          })
      );
    });
    return Promise.all(fetches).then(function (cssChunks) {
      var css = cssChunks.join("\n");
      return (
        "<!doctype html>\n" +
        '<html data-color-mode="' + theme + '">\n' +
        "<head>\n" +
        '<meta charset="utf-8">\n' +
        "<title>" + (initial.basename || "revelio") + "</title>\n" +
        "<style>" + css + "</style>\n" +
        "</head>\n" +
        "<body>\n" +
        contentEl.outerHTML +
        "\n</body>\n</html>\n"
      );
    });
  }

  function downloadHtml(html, filename) {
    var blob = new Blob([html], { type: "text/html;charset=utf-8" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () {
      URL.revokeObjectURL(url);
    }, 1000);
  }

  function postExport(html) {
    fetch("/api/export", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ html: html }),
    }).catch(function (e) {
      console.warn("revelio: failed to POST export", e);
    });
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
  events.addEventListener("export", function (evt) {
    var data = JSON.parse(evt.data);
    buildExportHtml().then(function (html) {
      if (data.server_side) {
        postExport(html);
      } else {
        downloadHtml(html, (initial.basename || "revelio") + ".html");
      }
    });
  });
  events.onerror = function () {
    console.warn("revelio: SSE connection lost — the preview will stop updating live");
  };
})();
