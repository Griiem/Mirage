const ALLOWED_PATHS = ["/v1/search/items/details"];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "*",
};

function jsonResponse(body, status) {
  return new Response(body, {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export default {
  async fetch(request) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (!ALLOWED_PATHS.includes(url.pathname)) {
      return jsonResponse(JSON.stringify({ errors: [{ message: "Path not allowed" }] }), 404);
    }

    const target = "https://catalog.roblox.com" + url.pathname + url.search;

    const upstream = await fetch(target, {
      headers: {
        Accept: "application/json",
        "User-Agent": "Mozilla/5.0",
      },
      cf: { cacheTtl: 60, cacheEverything: true },
    });

    const body = await upstream.text();

    return jsonResponse(body, upstream.status);
  },
};
