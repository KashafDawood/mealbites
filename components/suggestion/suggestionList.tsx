import { useEffect, useMemo, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";

interface DishSuggestion {
  id: string;
  dish_name: string;
  category: string;
  created_at: string;
  day: string;
  description?: string | null;
  dish_id?: string | null;
  reviewed_at?: string | null;
  reviewed_by?: string | null;
  status?: "pending" | "approved" | "rejected" | string | null;
  suggested_by?: string | null;
  vote_count?: number | null;
}

const SuggestionList = ({
  category,
  day,
}: {
  category: string;
  day: string;
}) => {
  const [suggestions, setSuggestions] = useState<DishSuggestion[]>([]);
  const [loading, setLoading] = useState();

  useEffect(() => {
    const ac = new AbortController();
    const fetchDishes = async () => {
      setLoading(true);
      try {
        const url = `/api/getSuggestedDishes${category ? `?category=${encodeURIComponent(category)}` : ""}${day ? `&day=${encodeURIComponent(day)}` : ""}`;
        const res = await fetch(url, { signal: ac.signal });
        const contentType = res.headers.get("content-type") || "";
        const json = contentType.includes("application/json")
          ? await res.json()
          : null;
        if (!res.ok) throw new Error(json?.error || "Failed to fetch dishes");
        const rows: DishSuggestion[] =
          json?.suggestions || json?.dishes || json?.data || [];
        const filtered = rows.filter(
          (dish) =>
            (!category || dish.category === category) &&
            (!day || dish.day === day),
        );
        setSuggestions(filtered);
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
  }, [category, day]);

  const sortedSuggestions = useMemo(
    () =>
      [...suggestions].sort((a, b) =>
        (b.created_at || "").localeCompare(a.created_at || ""),
      ),
    [suggestions],
  );

  const handleVote = async (suggestion_id: string) => {
    try {
      const response = await fetch("/api/givevote", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ suggestion_id }),
      });

      const data = await response.json();

      if (!response.ok) {
        // Handle specific error codes
        if (response.status === 409) {
          toast.error("You have already voted on this suggestion");
        } else if (response.status === 401) {
          toast.error("Please sign in to vote");
        } else {
          toast.error(data.error || "Failed to submit vote");
        }
        return;
      }

      // Update local state with new vote count
      setSuggestions((prev) =>
        prev.map((suggestion) =>
          suggestion.id === suggestion_id
            ? { ...suggestion, vote_count: data.suggestion.vote_count }
            : suggestion,
        ),
      );

      toast.success("Vote submitted successfully!");
    } catch (error) {
      console.error("Error submitting vote:", error);
      toast.error(
        error instanceof Error ? error.message : "Failed to submit vote",
      );
    }
  };

  return (
    <div className="space-y-4 px-4 py-6">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold text-foreground">
            Suggested dishes
          </h3>
          <p className="text-sm text-muted-foreground">
            Vote for the dishes you want to see on the menu.
          </p>
        </div>
        <Badge variant="secondary">
          {sortedSuggestions.length} suggestion
          {sortedSuggestions.length === 1 ? "" : "s"}
        </Badge>
      </div>

      {loading ? (
        <div className="grid gap-3 sm:grid-cols-2">
          {[...Array(4)].map((_, i) => (
            <Card key={i} className="border-border">
              <CardHeader className="space-y-2">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1 space-y-2">
                    <Skeleton className="h-5 w-32" />
                    <Skeleton className="h-4 w-24" />
                  </div>
                  <Skeleton className="h-6 w-20" />
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <Skeleton className="h-4 w-full" />
                <Skeleton className="h-4 w-3/4" />
                <div className="flex items-center justify-between">
                  <Skeleton className="h-4 w-32" />
                  <div className="flex items-center gap-2">
                    <Skeleton className="h-9 w-10" />
                    <Skeleton className="h-6 w-8" />
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : sortedSuggestions.length === 0 ? (
        <Card>
          <CardContent className="py-8 text-center">
            <p className="text-sm font-medium text-foreground">
              No suggestions yet
            </p>
            <p className="mt-1 text-sm text-muted-foreground">
              Be the first to suggest a dish for this day.
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {sortedSuggestions.map((dish) => (
            <Card key={dish.id} className="border-border">
              <CardHeader className="space-y-2">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <CardTitle className="text-base">
                      {dish.dish_name}
                    </CardTitle>
                    <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                      <span className="capitalize">{dish.day}</span>
                      <span>•</span>
                      <span className="capitalize">{dish.category}</span>
                    </div>
                  </div>
                  <Badge
                    variant={dish.status === "approved" ? "default" : "outline"}
                    className="capitalize"
                  >
                    {dish.status || "pending"}
                  </Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                {dish.description ? (
                  <p className="text-sm text-muted-foreground">
                    {dish.description}
                  </p>
                ) : null}

                <div className="flex items-center justify-between">
                  <div className="text-xs text-muted-foreground">
                    Suggested {dish.created_at ? "on " : ""}
                    {dish.created_at
                      ? new Date(dish.created_at).toLocaleDateString()
                      : "recently"}
                  </div>
                  <div className="flex items-center gap-2">
                    <Button
                      onClick={() => handleVote(dish.id)}
                      type="button"
                      variant="outline"
                      size="sm"
                      aria-label={`Vote ${dish.dish_name}`}
                    >
                      👍
                    </Button>
                    <div className="min-w-[2rem] text-center text-sm font-semibold">
                      {dish.vote_count ?? 0}
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
};

export default SuggestionList;
