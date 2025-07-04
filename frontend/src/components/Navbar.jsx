"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useCart } from "@/context/CartContext";

export default function Navbar() {
  const { cart = [] } = useCart() || {};
  const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);
  // or don't call fetchCart()

  const [user, setUser] = useState(null);
  const pathname = usePathname();
  const router = useRouter();
  
  
  useEffect(() => {
    const token = localStorage.getItem("token");
    if (!token) return; // ✅ skip if no token

    const stored = localStorage.getItem("user");
    if (stored) setUser(JSON.parse(stored));
  }, [pathname]);
  

  const handleLogout = () => {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    setUser(null);
    router.push("/login");
  };

  return (
    <nav className="bg-white shadow-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-6 py-4 flex justify-between items-center">
        {/* Logo */}
        <Link
          href="/"
          className="text-3xl font-extrabold bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-500 bg-clip-text text-transparent hover:opacity-90 transition-opacity"
        >
          ShopSphere
        </Link>

        {/* Navigation Links */}
        <div className="flex items-center space-x-6 text-sm font-medium text-gray-700">
          {!user ? (
            <>
              <NavLink href="/login" label="Login" />
              <NavLink href="/register" label="Register" />
            </>
          ) : (
            <>
              {/* Cart with badge */}
              <div className="relative">
                
                <Link
                  href="/cart"
                  className="text-gray-700 hover:text-indigo-600 font-semibold"
                >
                  🛒 Cart
                </Link>
                {totalItems > 0 && (
                  <span className="absolute -top-2 -right-3 bg-red-600 text-white text-xs w-5 h-5 rounded-full flex items-center justify-center">
                    {totalItems}
                  </span>
                )}
              </div>

              <NavLink href="/products" label="Products" />
              <NavLink href="/orders" label="Orders" />
              {user.is_admin && (
                <NavLink
                  href="/admin/manage-products"
                  label="Manage Products"
                />
              )}

              <span className="text-gray-400 hidden sm:inline">|</span>
              <span className="text-gray-500 hidden sm:inline">
                {user.email}
              </span>
              <button
                onClick={handleLogout}
                className="text-red-500 hover:text-red-700 transition-colors"
              >
                Logout
              </button>
            </>
          )}
        </div>
      </div>
    </nav>
  );
}

// 🔁 Reusable nav link
function NavLink({ href, label }) {
  return (
    <Link
      href={href}
      className="relative group text-gray-700 hover:text-indigo-600 transition duration-200"
    >
      {label}
      <span className="absolute left-0 -bottom-1 w-0 h-0.5 bg-indigo-600 transition-all group-hover:w-full"></span>
    </Link>
  );
}
