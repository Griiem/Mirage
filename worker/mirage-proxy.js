const ROUTES = [
  { pattern: /^\/v1\/search\/items\/details$/, upstream: "https://catalog.roblox.com", rewrite: (path) => path, binary: false },
  { pattern: /^\/v1\/bundles\/\d+\/details$/, upstream: "https://catalog.roblox.com", rewrite: (path) => path, binary: false },
  { pattern: /^\/v1\/asset$/, upstream: "https://assetdelivery.roblox.com", rewrite: () => "/v1/asset/", binary: true },
];

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
    const route = ROUTES.find((entry) => entry.pattern.test(url.pathname));

    if (!route) {
      return jsonResponse(JSON.stringify({ errors: [{ message: "Path not allowed" }] }), 404);
    }

    if (route.binary && !/^\d+$/.test(url.searchParams.get("id") || "")) {
      return jsonResponse(JSON.stringify({ errors: [{ message: "Invalid id" }] }), 400);
    }

    const target = route.upstream + route.rewrite(url.pathname) + url.search;

    const upstream = await fetch(target, {
      headers: {
        Accept: route.binary ? "*/*" : "application/json",
        "Accept-Language": "en-US,en;q=0.9",
        "User-Agent": "Mozilla/5.0",
      },
      redirect: "follow",
      cf: { cacheTtl: route.binary ? 3600 : 60, cacheEverything: true },
    });

    if (route.binary) {
      return new Response(upstream.body, {
        status: upstream.status,
        headers: {
          ...CORS_HEADERS,
          "Content-Type": upstream.headers.get("Content-Type") || "application/octet-stream",
        },
      });
    }

    return jsonResponse(await upstream.text(), upstream.status);
  },
};
