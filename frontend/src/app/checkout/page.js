"use client";

import { useCart } from "@/context/CartContext";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import toast from "react-hot-toast";
import API from "@/services/api";
import Loader from "@/components/Loader";
import ClientOnly from "@/components/ClientOnly";

export default function CheckoutPage() {
  const { cart, fetchCart } = useCart();
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(true);
  const router = useRouter();

  useEffect(() => {
    const refreshData = async () => {
      setRefreshing(true);
      try {
        await fetchCart(); // Ensure cart is latest
      } catch (err) {
        toast.error("Failed to load cart");
      } finally {
        setRefreshing(false);
      }
    };

    refreshData();
  }, []);

  const total = cart.reduce(
    (sum, item) => sum + item.product.price * item.quantity,
    0
  );

  const handleCheckout = async () => {
    setLoading(true);
    try {
      const user = JSON.parse(localStorage.getItem("user") || "{}");

      // Store cart in localStorage before Stripe redirect
      localStorage.setItem("cart_backup", JSON.stringify(cart));

      const res = await API.post("/create-checkout-session", {
        email: user?.email,
        items: cart.map((item) => ({
          id: item.product.id,
          name: item.product.name,
          price: item.product.price,
          quantity: item.quantity,
        })),
      });

      if (res.data.url) {
        window.location.href = res.data.url;
      } else {
        toast.error("Failed to initiate checkout");
      }
    } catch (err) {
      console.error(err);
      toast.error("Error during checkout");
    } finally {
      setLoading(false);
    }
  };

  return (
    <ClientOnly>
      <div className="max-w-3xl mx-auto py-10 px-4">
        <h1 className="text-3xl font-bold mb-6">🧾 Checkout</h1>

        {refreshing ? (
          <div className="flex justify-center py-20">
            <Loader size="lg" text="Loading checkout..." />
          </div>
        ) : cart.length === 0 ? (
          <p className="text-gray-500">Your cart is empty.</p>
        ) : (
          <>
            <ul className="divide-y border rounded-md mb-6">
              {cart.map(({ product, quantity }) => (
                <li
                  key={product.id}
                  className="p-4 flex justify-between items-center"
                >
                  <div>
                    <h2 className="text-lg font-semibold">{product.name}</h2>
                    <p className="text-sm text-gray-500">
                      ₹ {product.price} × {quantity}
                    </p>
                  </div>
                  <p className="font-bold">₹ {product.price * quantity}</p>
                </li>
              ))}
            </ul>

            <div className="flex justify-between items-center mb-4">
              <p className="text-xl font-semibold">Total:</p>
              <p className="text-2xl font-bold text-indigo-600">₹ {total}</p>
            </div>

            <button
              onClick={handleCheckout}
              disabled={loading}
              className="w-full bg-indigo-600 text-white py-3 rounded hover:bg-indigo-700 transition disabled:opacity-50 flex items-center justify-center"
            >
              {loading ? <Loader size="sm" /> : "Proceed to Payment 💳"}
            </button>
          </>
        )}
      </div>
    </ClientOnly>
  );
}
