"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import API from "@/services/api";
import toast from "react-hot-toast";
import Loader from "@/components/Loader";
import ClientOnly from "@/components/ClientOnly";

export default function OrdersPage() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (!token) {
      router.push("/login");
      return;
    }

    fetchOrders();
  }, [router]);

  const fetchOrders = async () => {
    try {
      const res = await API.get("/orders");
      setOrders(res.data);
    } catch (err) {
      toast.error("Failed to fetch orders.");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <ClientOnly>
      <div className="min-h-screen bg-gray-50 px-6 py-10">
        <h1 className="text-3xl font-bold text-indigo-700 mb-8 text-center">
          📦 My Orders
        </h1>

        {loading ? (
          <div className="flex justify-center mt-20">
            <Loader size="lg" text="Loading orders..." />
          </div>
        ) : orders.length === 0 ? (
          <p className="text-center text-gray-400">No orders placed yet.</p>
        ) : (
          <div className="max-w-4xl mx-auto space-y-6">
            {orders.map((order) => (
              <div key={order.id} className="bg-white shadow rounded-lg p-6">
                <div className="flex justify-between mb-2">
                  <p className="text-sm text-gray-600">
                    🧾 Order ID: {order.id}
                  </p>
                  <p className="text-sm text-gray-500">
                    Status:{" "}
                    <span className="text-green-600">{order.status}</span>
                  </p>
                </div>
                <ul className="text-sm text-gray-800 space-y-1 mb-2">
                  {order.items.map((item) => (
                    <li key={item.id}>
                      <strong>{item.product_name}</strong> × {item.quantity} — ₹
                      {item.price}
                    </li>
                  ))}
                </ul>
                <p className="font-bold text-right text-indigo-700">
                  Total: ₹{order.total}
                </p>
              </div>
            ))}
          </div>
        )}
      </div>
    </ClientOnly>
  );
}
