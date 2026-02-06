import { NextResponse } from "next/server";
import { z } from "zod";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const bodySchema = z
  .object({
    dish_id: z.string().uuid().optional(),
    name: z.string().min(1).max(100).optional(),
    category: z.enum(["regular", "meat", "rice", "sabzi"]),
    day: z.enum(["monday", "tuesday", "wednesday", "thursday", "friday"]),
  })
  .refine((data) => Boolean(data.dish_id || data.name), {
    message: "Either dish_id or name must be provided",
    path: ["dish_id"],
  });

export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  const parsedBody = bodySchema.safeParse(body);

  if (!parsedBody.success) {
    return NextResponse.json(
      { error: "Invalid payload", details: parsedBody.error.format() },
      { status: 400 },
    );
  }

  const { dish_id, name, category, day } = parsedBody.data;

  // Get current user
  const authClient = await createClient();
  const {
    data: { user },
  } = await authClient.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const adminClient = createAdminClient();

  let finalDishId = dish_id;
  let dishName: string | null = null;

  if (dish_id) {
    // Fetch the dish name from the dishes table
    const { data: dish, error: dishError } = await adminClient
      .from("dishes")
      .select("name")
      .eq("id", dish_id)
      .single();

    if (dishError) {
      return NextResponse.json(
        { error: `Failed to fetch dish: ${dishError.message}` },
        { status: 500 },
      );
    }
    dishName = dish?.name || null;
  }

  // If it's a new dish suggestion (name provided), create a dish first
  if (name && !dish_id) {
    const { data: newDish, error: dishError } = await adminClient
      .from("dishes")
      .insert([
        { name: name.trim(), category, is_active: false, created_by: user.id },
      ])
      .select("id, name")
      .single();

    if (dishError) {
      return NextResponse.json(
        { error: `Failed to create dish: ${dishError.message}` },
        { status: 500 },
      );
    }
    finalDishId = newDish?.id;
    dishName = newDish?.name || null;
  }

  // Create the suggestion pointing to the dish
  const insertData: Record<string, any> = {
    dish_id: finalDishId,
    dish_name: dishName,
    category,
    day,
    suggested_by: user.id,
  };

  // If it's a new dish suggestion, mark as pending
  if (name && !dish_id) {
    insertData.status = "pending";
  }

  const { data, error } = await adminClient
    .from("meal_suggestions")
    .insert([insertData])
    .select()
    .single();

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ suggestion: data }, { status: 201 });
}
