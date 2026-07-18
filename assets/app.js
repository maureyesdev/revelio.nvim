// Phase 2: render the full buffer as Markdown via markdown-it (GFM tables +
// strikethrough are built into its default preset) plus the task-lists
// plugin for GitHub-style checkboxes. Phase 3: live re-render on buffer
// change. Phase 4: syntax-highlight fenced code blocks via highlight.js —
// a fence whose language highlight.js doesn't recognize (e.g. a
// ```mermaid block, since mermaid_fences = "plain" in v1) falls through to
// markdown-it's own default escaping, i.e. renders as plain code. Scroll
// sync (Phase 5) and theme switching (Phase 6) hook in below.
(function () {
  var payloadEl = document.getElementById("revelio-payload");
  var initial = { source: "" };
  try {
    initial = JSON.parse(payloadEl.textContent);
  } catch (e) {
    console.error("revelio: could not parse initial payload", e);
  }

  var placeholderEl = document.getElementById("placeholder");
  var contentEl = document.getElementById("content");

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

  function render(source) {
    if (placeholderEl) {
      placeholderEl.remove();
      placeholderEl = null;
    }
    contentEl.innerHTML = md.render(source || "");
  }

  render(initial.source);

  var events = new EventSource("/events");
  events.addEventListener("source", function (evt) {
    var data = JSON.parse(evt.data);
    render(data.source);
  });
  events.onerror = function () {
    console.warn("revelio: SSE connection lost — the preview will stop updating live");
  };
})();
