"use client";

// import Image from "next/image";
import { useState } from "react";
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from "@/components/ui/drawer";
import { Button } from "@/components/ui/button";
import SuggestionContent from "@/components/suggestion/suggestionContent";
import SuggestionList from "@/components/suggestion/suggestionList";

const workingDays = [
  {
    day: "Mon",
    fullDay: "monday",
    accent: "bg-emerald-500",
    category: "regular",
    image: "",
    icon: "🍽️",
  },
  {
    day: "Tue",
    fullDay: "tuesday",
    accent: "bg-amber-500",
    category: "meat",
    image: "",
    icon: "🍗",
  },
  {
    day: "Wed",
    fullDay: "wednesday",
    accent: "bg-blue-500",
    category: "rice",
    image: "",
    icon: "🍚",
  },
  {
    day: "Thu",
    fullDay: "thursday",
    accent: "bg-rose-500",
    category: "sabzi",
    image: "",
    icon: "🥦",
  },
  {
    day: "Fri",
    fullDay: "friday",
    accent: "bg-purple-500",
    category: "meat",
    image: "",
    icon: "🍛",
  },
];

const Suggestion = () => {
  const [openDrawer, setOpenDrawer] = useState<string | null>(null);

  return (
    <main className="min-h-screen bg-background px-4 py-12 sm:px-6 lg:px-8 lg:py-20">
      <div className="mx-auto max-w-6xl">
        {/* Header */}
        <div className="mb-12 lg:mb-16">
          <div className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-4 py-1.5 text-xs font-medium text-muted-foreground shadow-sm">
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-500"></span>
            Weekly Menu Planning
          </div>
          <h1 className="mt-6 text-4xl font-semibold tracking-tight text-foreground sm:text-5xl lg:text-6xl">
            Select your day
          </h1>
          <p className="mt-4 text-lg text-muted-foreground sm:text-xl">
            Personalized meal suggestions for your working week
          </p>
        </div>

        {/* Days Grid */}
        <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-5 lg:gap-5">
          {workingDays.map((item, index) => (
            <Drawer
              key={item.day}
              open={openDrawer === item.day}
              onOpenChange={(open) => setOpenDrawer(open ? item.day : null)}
            >
              <DrawerTrigger asChild>
                <button
                  className="group relative overflow-hidden rounded-2xl border border-border bg-card text-left shadow-sm transition-all duration-300 hover:scale-[1.02] hover:border-border hover:shadow-xl active:scale-[0.98] lg:rounded-3xl"
                  style={{ animationDelay: `${index * 50}ms` }}
                >
                  {/* Background Image with Overlay */}
                  {/* <div className="absolute inset-0">
                    <Image
                      src={`/${item.image}.png`}
                      alt={item.category}
                      fill
                      className="object-cover"
                      sizes="(max-width: 768px) 50vw, 20vw"
                      priority={index < 2}
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-black/20 transition-opacity duration-300 group-hover:from-black/70 group-hover:via-black/30 group-hover:to-black/10" />
                  </div> */}

                  {/* Accent line */}
                  <div
                    className={`absolute left-0 top-0 z-10 h-full w-1 ${item.accent} transition-all duration-300 group-hover:w-1.5`}
                  />

                  {/* Content */}
                  <div className="relative z-10 p-6 sm:p-8">
                    <div className="mb-8 sm:mb-12">
                      <div className="text-5xl font-bold tracking-tighter text-foreground drop-shadow-lg sm:text-6xl lg:text-7xl">
                        {item.day}{" "}
                        <span className="ml-2 text-4xl lg:text-5xl">
                          {item.icon}
                        </span>
                      </div>
                    </div>

                    <div className="space-y-1.5">
                      <div className="text-sm font-medium capitalize text-muted-foreground drop-shadow">
                        {item.category}
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="h-px flex-1 bg-muted/30 transition-colors group-hover:bg-muted/50" />
                        <svg
                          className="h-4 w-4 text-muted-foreground/60 transition-all duration-300 group-hover:translate-x-1 group-hover:text-muted-foreground"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M9 5l7 7-7 7"
                          />
                        </svg>
                      </div>
                    </div>
                  </div>
                </button>
              </DrawerTrigger>
              <DrawerContent>
                <DrawerHeader>
                  <DrawerTitle className="capitalize">
                    {item.fullDay}
                  </DrawerTitle>
                  <DrawerDescription className="capitalize">
                    {item.category}
                  </DrawerDescription>
                </DrawerHeader>

                <SuggestionContent
                  category={item.category}
                  day={item.fullDay}
                  onClose={() => setOpenDrawer(null)}
                />

                <SuggestionList category={item.category} day={item.fullDay} />

                <DrawerFooter>
                  <Button>View Menu</Button>
                  <DrawerClose asChild>
                    <Button variant="outline">Close</Button>
                  </DrawerClose>
                </DrawerFooter>
              </DrawerContent>
            </Drawer>
          ))}
        </div>
      </div>
    </main>
  );
};

export default Suggestion;
