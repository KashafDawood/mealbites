import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";

export async function GET() {
  const adminClient = createAdminClient();

  const { data, error } = await adminClient
    .from("meal_suggestions")
    .select("*")
    .order("created_at", { ascending: true });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ dishes: data }, { status: 200 });
}
