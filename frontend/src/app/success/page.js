"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import API from "@/services/api";
import toast from "react-hot-toast";
import { useCart } from "@/context/CartContext"; // ✅ Import cart context

export default function SuccessPage() {
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const { fetchCart } = useCart(); // ✅ Destructure fetchCart

  useEffect(() => {
    const clearCartAfterPayment = async () => {
      try {
        await API.delete("/cart/clear"); // 🗑️ Backend clear
        await fetchCart(); // 🔁 Immediately refresh cart context
        toast.success("🎉 Payment successful! Cart cleared.");
      } catch (err) {
        toast.error("Error clearing cart.");
        console.error(err);
      } finally {
        setLoading(false);
      }
    };

    clearCartAfterPayment();
  }, []);

  return (
    <div className="min-h-screen flex flex-col justify-center items-center px-4">
      <h1 className="text-3xl font-bold text-green-600 mb-2">
        ✅ Payment Successful
      </h1>
      <p className="text-gray-600 mb-6 text-center">
        Thank you for your purchase! You can now continue shopping.
      </p>

      {loading ? (
        <div className="text-gray-500">Clearing your cart...</div>
      ) : (
        <button
          onClick={() => router.push("/products")}
          className="bg-indigo-600 text-white px-6 py-3 rounded hover:bg-indigo-700 transition"
        >
          Back to Products
        </button>
      )}
    </div>
  );
}
