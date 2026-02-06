"use client";
import React from "react";
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

export default function GoogleAuthButton({
  redirectTo,
  children = "Continue with Google",
}: {
  redirectTo?: string;
  children?: React.ReactNode;
}) {
  const handleGoogle = async () => {
    try {
      await supabase.auth.signInWithOAuth({
        provider: "google",
        options: redirectTo ? { redirectTo } : undefined,
      });
      // Supabase will redirect the browser to the provider
    } catch (err) {
      console.error("Google sign-in failed", err);
      // show toast / UI feedback
    }
  };

  return (
    <button
      type="button"
      onClick={handleGoogle}
      className="inline-flex items-center px-4 py-2 rounded-md border w-full justify-center bg-white text-gray-700 hover:bg-gray-50 focus:outline-none"
    >
      {/* simple Google icon (optional) */}
      <svg className="w-4 h-4 mr-2" viewBox="0 0 24 24" fill="none">
        <path
          d="M21.35 11.1h-9.2v2.8h5.3c-.23 1.3-1.04 2.4-2.22 3.12v2.6h3.58c2.1-1.93 3.3-4.78 3.3-8.52 0-.6-.05-1.18-.18-1.72z"
          fill="#4285F4"
        />
        <path
          d="M12.15 22c2.97 0 5.46-.98 7.28-2.66l-3.58-2.6c-.99.66-2.27 1.05-3.7 1.05-2.85 0-5.26-1.92-6.12-4.5H2.32v2.82C4.12 19.9 7.8 22 12.15 22z"
          fill="#34A853"
        />
        <path
          d="M6.03 13.89a7.19 7.19 0 010-3.78V7.3H2.32a10.1 10.1 0 000 9.41l3.71-2.82z"
          fill="#FBBC05"
        />
        <path
          d="M12.15 6.4c1.6 0 3.04.55 4.17 1.64l3.13-3.13C17.6 2.9 15.11 2 12.15 2 7.8 2 4.12 4.1 2.32 7.3l3.71 2.82C6.89 8.32 9.3 6.4 12.15 6.4z"
          fill="#EA4335"
        />
      </svg>
      {children}
    </button>
  );
}
