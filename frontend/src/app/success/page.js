"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import API from "@/services/api";
import toast from "react-hot-toast";
import { useCart } from "@/context/CartContext";

export default function SuccessPage() {
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const { fetchCart } = useCart(); // ❌ don't use cart context here

  useEffect(() => {
    const handleSuccess = async () => {
      try {
        // ✅ Load backup cart from localStorage
        const raw = localStorage.getItem("cart_backup");
        const cachedCart = raw ? JSON.parse(raw) : [];

        if (!cachedCart.length) {
          toast.error("Cart is empty. Cannot place order.");
          return;
        }

        const orderData = {
          items: cachedCart.map((item) => ({
            product_id: item.product.id,
            product_name: item.product.name,
            quantity: item.quantity,
            price: item.product.price,
          })),
          total: cachedCart.reduce(
            (sum, item) => sum + item.quantity * item.product.price,
            0
          ),
        };

        console.log("🧾 Final Order:", orderData);

        await API.post("/orders", orderData);
        toast.success("🎉 Order placed successfully!");

        await API.delete("/cart/clear");
        await fetchCart();
        localStorage.removeItem("cart_backup"); // ✅ cleanup
      } catch (err) {
        toast.error("Something went wrong.");
        console.error("❌ Order error:", err);
      } finally {
        setLoading(false);
      }
    };

    handleSuccess();
  }, []);

  return (
    <div className="min-h-screen flex flex-col justify-center items-center px-4">
      <h1 className="text-3xl font-bold text-green-600 mb-2">
        ✅ Payment Successful
      </h1>
      <p className="text-gray-600 mb-6 text-center">
        Thank you for your purchase!
      </p>

      {loading ? (
        <div className="text-gray-500">Finalizing your order...</div>
      ) : (
        <button
          onClick={() => router.push("/orders")}
          className="bg-indigo-600 text-white px-6 py-3 rounded hover:bg-indigo-700 transition"
        >
          View My Orders
        </button>
      )}
    </div>
  );
}
