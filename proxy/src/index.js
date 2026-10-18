// Cloudflare Worker: a proxy between the iPad and the zweef.app (GlidingApp) API.
// The zweef.app API key stays here; the iPad only ever sends a device token of its own.
//
// Secrets / vars (wrangler secret put ...):
//   ZWEEF_API_KEY  — the X-API-KEY from the zweef.app admin
//   CLUB           — the club's schema name
//   DEVICE_TOKENS  — a comma-separated list of valid device tokens (revocable)

const ALLOWED = [
  { method: "GET", path: /^\/club\.json$/ },
  { method: "GET", path: /^\/accounts\.json$/ },
  { method: "GET", path: /^\/material\.json$/ },
  { method: "GET", path: /^\/maintenance-hours\/periods\.json$/ },
  { method: "GET", path: /^\/maintenance-hours\/(current|\d+)\/hours\.json$/ },
  { method: "POST", path: /^\/maintenance-hours\.json$/ },
];

// Only these query parameters are forwarded.
const ALLOWED_QUERY = new Set(["id", "inactive"]);

export default {
  async fetch(request, env) {
    const auth = request.headers.get("Authorization") || "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    const valid = (env.DEVICE_TOKENS || "").split(",").map((t) => t.trim()).filter(Boolean);
    if (!token || !valid.includes(token)) {
      return json({ error: "unauthorized" }, 401);
    }

    const url = new URL(request.url);
    const rule = ALLOWED.find((r) => r.method === request.method && r.path.test(url.pathname));
    if (!rule) {
      return json({ error: "not_allowed" }, 403);
    }

    const upstream = new URL(`https://admin.gliding.app/club/${encodeURIComponent(env.CLUB)}/api${url.pathname}`);
    for (const [k, v] of url.searchParams) {
      if (ALLOWED_QUERY.has(k)) upstream.searchParams.set(k, v);
    }

    const init = {
      method: request.method,
      headers: { "X-API-KEY": env.ZWEEF_API_KEY, "Accept": "application/json" },
    };
    if (request.method === "POST") {
      init.headers["Content-Type"] = "application/json";
      init.body = await request.text();
    }

    const res = await fetch(upstream.toString(), init);
    const body = await res.text();
    return new Response(body, {
      status: res.status,
      headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" },
    });
  },
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json" } });
}
