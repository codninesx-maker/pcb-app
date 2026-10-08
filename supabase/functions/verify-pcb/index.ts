import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // Handle CORS preflight requests if needed
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const { pcb_licence, name } = await req.json()

    if (!pcb_licence || !name) {
      return new Response(
        JSON.stringify({ verified: false, message: "Missing license or name" }),
        { headers: { "Content-Type": "application/json" }, status: 400 }
      )
    }

    // --- OPTION A: Query an official external registry or API ---
    /*
    const externalRes = await fetch(`https://api.pcb-gov.example/verify?license=${bpc_licence}`);
    const externalData = await externalRes.json();
    const isValid = externalData.registeredName.toLowerCase() === name.toLowerCase();
    */

    // --- OPTION B: Check against a secure table in your Supabase database ---
    // You can use the Supabase JS client inside the edge function using service role key
    /*
    import { createClient } from 'jsr:@supabase/supabase-js@2'
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    const { data } = await supabase
      .from('pcb_registry')
      .select('*')
      .eq('license_number', bpc_licence)
      .single()

    const isValid = data && data.name.toLowerCase() === name.toLowerCase();
    */

    // Mock validation logic for testing structure (Replace with Option A or B above)
    const isMockValid = pcb_licence.length >= 5 && name.trim().length > 2;

    return new Response(
      JSON.stringify({
        verified: isMockValid,
        message: isMockValid ? "License verified successfully" : "Registry record mismatch"
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": '*'
        },
        status: 200
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ verified: false, error: error.message }),
      { headers: { "Content-Type": "application/json" }, status: 500 }
    )
  }
})