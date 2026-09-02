import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const { public_id } = await req.json();
  const cloudName = Deno.env.get("CLOUDINARY_CLOUD_NAME");
  const apiKey = Deno.env.get("CLOUDINARY_API_KEY");
  const apiSecret = Deno.env.get("CLOUDINARY_API_SECRET");
  const timestamp = Math.round(new Date().getTime() / 1000);

  // Generate SHA-1 signature
  const signatureInput = `public_id=${public_id}&timestamp=${timestamp}${apiSecret}`;
  const msgUint8 = new TextEncoder().encode(signatureInput);
  const hashBuffer = await crypto.subtle.digest("SHA-1", msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const signature = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");

  // Call Cloudinary API to delete
  const response = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/destroy`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      public_id,
      timestamp: timestamp.toString(),
      api_key: apiKey!,
      signature,
    }),
  });

  const data = await response.json();
  return new Response(JSON.stringify(data), { 
    headers: { "Content-Type": "application/json" },
    status: response.status 
  });
});