// Storage Script (Last Working Version / Feb. 15th, 2026)

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "*",
    };

    // Respond to browser pre-checks
    if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

    // THE SAVE LOGIC
    if (url.pathname.includes("save")) {
      try {
        const bodyText = await request.text();
        const params = new URLSearchParams(bodyText);
        
        // Use fallbacks if the form parsing fails
        const id = params.get("id") || "UnknownPlayer";
        const data = params.get("data") || "NoData";

        await env.POKEMON_STORAGE.put(id, data);
        
        return new Response("OK", { status: 200, headers: corsHeaders });
      } catch (e) {
        return new Response("Error: " + e.message, { status: 200, headers: corsHeaders });
      }
    }

    return new Response("GBA Online", { headers: corsHeaders });
  }
};

// 
