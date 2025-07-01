"use client";
// import "../styles/globals.css";
import { CartProvider } from "@/context/CartContext";
import { Toaster } from "react-hot-toast";
import "@/styles/globals.css";
import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";
import NProgress from "nprogress";
import Navbar from '@/components/Navbar';


export default function RootLayout({ children }) {
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    NProgress.configure({ showSpinner: false });

    const start = () => NProgress.start();
    const done = () => NProgress.done();

    router.events?.on("routeChangeStart", start);
    router.events?.on("routeChangeComplete", done);
    router.events?.on("routeChangeError", done);

    return () => {
      router.events?.off("routeChangeStart", start);
      router.events?.off("routeChangeComplete", done);
      router.events?.off("routeChangeError", done);
    };
  }, [router]);

  return (
    <html lang="en">
      <body>
        <Navbar />
        <CartProvider>
        <Toaster position="top-right" />
          {children}
        </CartProvider>
      </body>
    </html>
  );
}
