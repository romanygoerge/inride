// Follow Deno and Supabase Edge Functions runtime standards
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let query = "";
    let lat = 30.3800;
    let lng = 30.5100;
    let radius = 50000;

    if (req.method === "GET") {
      const url = new URL(req.url);
      query = url.searchParams.get("query") || "";
      lat = parseFloat(url.searchParams.get("lat") || "30.3800");
      lng = parseFloat(url.searchParams.get("lng") || "30.5100");
      radius = parseInt(url.searchParams.get("radius") || "50000", 10);
    } else if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      query = body.query || "";
      lat = parseFloat(body.lat ?? "30.3800");
      lng = parseFloat(body.lng ?? "30.5100");
      radius = parseInt(body.radius ?? "50000", 10);
    }

    if (!query || query.trim().length === 0) {
      return new Response(JSON.stringify({ status: "OK", results: [] }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // Google Maps API Key securely read from Supabase Secrets
    const apiKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "GOOGLE_MAPS_API_KEY is not configured on the server." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    const googleUrl = new URL("https://maps.googleapis.com/maps/api/place/textsearch/json");
    googleUrl.searchParams.set("query", query);
    googleUrl.searchParams.set("location", `${lat},${lng}`);
    googleUrl.searchParams.set("radius", radius.toString());
    googleUrl.searchParams.set("language", "ar");
    googleUrl.searchParams.set("region", "eg");
    googleUrl.searchParams.set("key", apiKey);

    const googleRes = await fetch(googleUrl.toString(), {
      headers: { "Accept": "application/json" },
    });

    const data = await googleRes.json();
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
