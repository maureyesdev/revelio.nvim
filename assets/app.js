// Phase 1: just open the SSE connection so the server can see a connected
// client (server.client_count() > 0). Rendering wired up in Phase 2/3.
const events = new EventSource("/events");

events.addEventListener("source", (e) => {
  // eslint-disable-next-line no-console
  console.log("revelio: received source event", JSON.parse(e.data));
});
