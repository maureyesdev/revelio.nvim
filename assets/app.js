// Phase 2: render the full buffer as Markdown via markdown-it (GFM tables +
// strikethrough are built into its default preset) plus the task-lists
// plugin for GitHub-style checkboxes. Live re-render on buffer change
// (Phase 3), syntax highlighting (Phase 4), scroll sync (Phase 5), and
// theme switching (Phase 6) all hook into render() below.
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

  var md = window.markdownit();
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
