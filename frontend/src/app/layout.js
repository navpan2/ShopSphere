"use client";

import { CartProvider } from "@/context/CartContext";
import { Toaster } from "react-hot-toast";
import "@/styles/globals.css";
import Navbar from "@/components/Navbar";

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <CartProvider>
          <Navbar />
          <Toaster position="top-right" />
          {children}
        </CartProvider>
      </body>
    </html>
  );
}
