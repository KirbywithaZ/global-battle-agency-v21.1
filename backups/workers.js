// Storage

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "*",
    };

    if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

    // SAVE (Deposit)
    if (url.pathname.includes("save")) {
      const bodyText = await request.text();
      const params = new URLSearchParams(bodyText);
      const id = params.get("id");
      const data = params.get("data");
      await env.POKEMON_STORAGE.put(id, data);
      return new Response("OK", { headers: corsHeaders });
    }

    // GET (Withdrawal part 1)
    if (url.pathname.includes("get")) {
      const id = url.searchParams.get("id");
      const data = await env.POKEMON_STORAGE.get(id);
      return new Response(data || "NOT_FOUND", { headers: corsHeaders });
    }

    // DELETE (Withdrawal part 2 - Anti-Cloning)
    if (url.pathname.includes("delete")) {
      const id = url.searchParams.get("id");
      await env.POKEMON_STORAGE.delete(id);
      return new Response("DELETED", { headers: corsHeaders });
    }

    return new Response("GBA Online Active", { headers: corsHeaders });
  }
};
