import { Button } from "@/components/ui/button";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useEffect, useState } from "react";
import { Input } from "../ui/input";
import { toast } from "sonner";

const SuggestionContent = ({
  category,
  day,
  onClose,
}: {
  category: string;
  day: string;
  onClose?: () => void;
}) => {
  const [dishSuggestion, setDishSuggestion] = useState("");
  const [dishes, setDishes] = useState<
    { id: string; name: string; category: string; day: string }[]
  >([]);
  const [selectedDish, setSelectedDish] = useState("");
  const [loading, setLoading] = useState(false);
  const [isCollapsibleOpen, setIsCollapsibleOpen] = useState(false);

  useEffect(() => {
    const ac = new AbortController();
    const fetchDishes = async () => {
      setLoading(true);
      try {
        const url = `/api/getDishes${category ? `?category=${encodeURIComponent(category)}` : ""}`;
        const res = await fetch(url, { signal: ac.signal });
        const contentType = res.headers.get("content-type") || "";
        const json = contentType.includes("application/json")
          ? await res.json()
          : null;
        if (!res.ok) throw new Error(json?.error || "Failed to fetch dishes");
        setDishes(json.dishes || []);
      } catch (err: unknown) {
        // Narrow the error type instead of using `any`
        if (err instanceof DOMException) {
          if (err.name !== "AbortError")
            console.error("Failed to fetch dishes:", err);
        } else if (err instanceof Error) {
          if (err.name !== "AbortError")
            console.error("Failed to fetch dishes:", err);
        } else {
          console.error("Failed to fetch dishes:", err);
        }
      } finally {
        setLoading(false);
      }
    };
    fetchDishes();
    return () => ac.abort();
  }, [category]);

  const dishesName = dishes
    .filter((dish) => dish.category === category)
    .map((dish) => dish.name);

  const submitSuggestion = async () => {
    try {
      // client-side validation: ensure we have either an existing dish id or a new name
      const dish_id =
        selectedDish !== "other"
          ? dishes.find(
              (d) =>
                d.name.trim().toLowerCase() ===
                selectedDish.trim().toLowerCase(),
            )?.id
          : undefined;
      const payload = {
        dish_id,
        name: dishSuggestion || undefined,
        category,
        day,
      };

      if (!payload.dish_id && !payload.name) {
        toast.error(
          "Please select an existing dish or enter a new suggestion.",
        );
        return;
      }

      const res = await fetch("/api/createDishSuggestion", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });
      const contentType = res.headers.get("content-type") || "";
      const json = contentType.includes("application/json")
        ? await res.json()
        : null;
      if (!res.ok) {
        console.error("Create suggestion failed", {
          status: res.status,
          body: json,
        });
        throw new Error(json?.error || "Failed to create dish suggestion");
      }
      // success: clear input and optionally inform parent
      setDishSuggestion("");
      setSelectedDish("");
      setIsCollapsibleOpen(false);
      toast.promise(Promise.resolve(), {
        loading: "Submitting your suggestion...",
        success: "Thank you for your suggestion!",
        error: "Failed to submit your suggestion.",
      });
      // Close drawer after successful submission
      onClose?.();
    } catch (error) {
      console.error("Failed to submit suggestion:", error);
    }
  };

  return (
    <div className="px-4">
      {!loading && (
        <Collapsible
          open={isCollapsibleOpen}
          onOpenChange={setIsCollapsibleOpen}
        >
          <CollapsibleTrigger asChild>
            <Button className="w-full" variant="outline">
              Add Suggestion
            </Button>
          </CollapsibleTrigger>
          <CollapsibleContent>
            <Card className="mt-4">
              <CardHeader>
                <CardTitle>Suggest a {category} dish</CardTitle>
                <CardDescription>
                  Add your favorite {category} dish to our menu. Examples:{" "}
                  {dishesName.slice(0, 3).join(", ")}
                </CardDescription>
                {/* <CardAction>Card Action</CardAction> */}
              </CardHeader>
              <CardContent>
                <Select
                  value={selectedDish}
                  onValueChange={(val) => setSelectedDish(val)}
                >
                  <SelectTrigger className="w-full">
                    <SelectValue placeholder="Select a dish" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectGroup>
                      {dishesName.map((dishName) => (
                        <SelectItem key={dishName} value={dishName}>
                          {dishName}
                        </SelectItem>
                      ))}
                      <SelectItem value="other">Suggest New Dish</SelectItem>
                    </SelectGroup>
                  </SelectContent>
                </Select>
                {selectedDish === "other" && (
                  <Input
                    className="mt-4"
                    value={dishSuggestion}
                    onChange={(e) => setDishSuggestion(e.target.value)}
                    placeholder={`Suggest a new ${category} dish`}
                  />
                )}
              </CardContent>
              <CardFooter>
                <Button
                  disabled={
                    !selectedDish ||
                    (selectedDish === "other" && !dishSuggestion)
                  }
                  onClick={submitSuggestion}
                >
                  Submit Suggestion
                </Button>
              </CardFooter>
            </Card>
          </CollapsibleContent>
        </Collapsible>
      )}
    </div>
  );
};

export default SuggestionContent;
