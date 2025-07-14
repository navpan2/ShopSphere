"use client";

import { useEffect, useState } from "react";
import { useCart } from "@/context/CartContext";
import Image from "next/image";
import toast from "react-hot-toast";
import { useRouter } from "next/navigation";
import Loader from "@/components/Loader";
import ClientOnly from "@/components/ClientOnly";

export default function CartPage() {
  const { cart, updateCartItem, removeFromCart, fetchCart } = useCart();
  const [loadingActions, setLoadingActions] = useState({});
  const [refreshing, setRefreshing] = useState(false);
  const router = useRouter();

  useEffect(() => {
    // Refresh cart data when page loads
    refreshCart();
  }, []);

  const refreshCart = async () => {
    setRefreshing(true);
    try {
      await fetchCart();
    } catch (err) {
      toast.error("Failed to refresh cart");
    } finally {
      setRefreshing(false);
    }
  };

  const setActionLoading = (productId, isLoading) => {
    setLoadingActions((prev) => ({ ...prev, [productId]: isLoading }));
  };

  const handleUpdate = async (productId, newQty, stock) => {
    if (newQty > stock) {
      toast.error("Cannot add more than available stock.");
      return;
    }

    setActionLoading(productId, true);
    try {
      await updateCartItem(productId, newQty);
      await refreshCart(); // Refresh to get latest stock
    } catch (err) {
      toast.error(err.message || "Failed to update quantity");
    } finally {
      setActionLoading(productId, false);
    }
  };

  const handleRemove = async (productId) => {
    setActionLoading(productId, true);
    try {
      await removeFromCart(productId);
    } catch (err) {
      toast.error(err.message || "Failed to remove item");
    } finally {
      setActionLoading(productId, false);
    }
  };

  const getTotal = () =>
    cart.reduce((total, item) => total + item.quantity * item.product.price, 0);

  return (
    <ClientOnly>
      <div className="min-h-screen bg-gray-50 px-6 py-10">
        <div className="max-w-4xl mx-auto">
          <div className="flex justify-between items-center mb-8">
            <h1 className="text-3xl font-bold text-indigo-700">
              🛍️ Your Shopping Cart
            </h1>
            <button
              onClick={refreshCart}
              disabled={refreshing}
              className="text-sm bg-gray-200 px-3 py-1 rounded hover:bg-gray-300 disabled:opacity-50"
            >
              {refreshing ? <Loader size="sm" /> : "Refresh"}
            </button>
          </div>

          {refreshing && cart.length === 0 ? (
            <div className="flex justify-center mt-20">
              <Loader size="lg" text="Loading cart..." />
            </div>
          ) : cart.length === 0 ? (
            <p className="text-center text-gray-500 mt-20 text-lg">
              Your cart is empty.
            </p>
          ) : (
            <div className="space-y-6">
              {cart.map(({ id, product, quantity }) => {
                const isLoading = loadingActions[product.id];

                return (
                  <div
                    key={id}
                    className="flex items-center bg-white shadow-md rounded-lg p-4 group relative"
                  >
                    <div className="w-24 h-24 bg-gray-100 rounded overflow-hidden mr-4">
                      <Image
                        src={product.image_url || "/placeholder.png"}
                        alt={product.name}
                        width={96}
                        height={96}
                        className="object-cover w-full h-full"
                      />
                    </div>

                    <div className="flex-1">
                      <h2 className="text-lg font-semibold text-gray-800">
                        {product.name}
                      </h2>
                      <p className="text-sm text-gray-500 mt-1">
                        ₹{product.price} × {quantity} = ₹
                        {product.price * quantity}
                      </p>
                      <p className="text-xs text-gray-400 mt-1">
                        Stock available: {product.stock}
                      </p>

                      <div className="flex items-center mt-2 space-x-2">
                        {isLoading ? (
                          <Loader size="sm" />
                        ) : (
                          <>
                            <button
                              className="px-3 py-1 bg-indigo-600 text-white rounded hover:bg-indigo-700 disabled:opacity-50"
                              onClick={() =>
                                handleUpdate(
                                  product.id,
                                  quantity - 1,
                                  product.stock
                                )
                              }
                              disabled={quantity <= 1 || isLoading}
                            >
                              −
                            </button>
                            <span className="px-3 text-gray-800">
                              {quantity}
                            </span>
                            <button
                              className="px-3 py-1 bg-indigo-600 text-white rounded hover:bg-indigo-700 disabled:opacity-50"
                              onClick={() =>
                                handleUpdate(
                                  product.id,
                                  quantity + 1,
                                  product.stock
                                )
                              }
                              disabled={quantity >= product.stock || isLoading}
                            >
                              +
                            </button>
                          </>
                        )}
                      </div>
                    </div>

                    <button
                      onClick={() => handleRemove(product.id)}
                      disabled={isLoading}
                      className="absolute top-2 right-2 text-sm bg-red-500 text-white px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition disabled:opacity-50"
                    >
                      {isLoading ? "..." : "Remove"}
                    </button>
                  </div>
                );
              })}

              {/* Total & Checkout */}
              <div className="text-right text-xl font-semibold text-gray-700 mt-6">
                Total: ₹ {getTotal()}
              </div>

              <div className="flex justify-end">
                <button
                  onClick={() => router.push("/checkout")}
                  className="mt-4 bg-indigo-600 text-white px-6 py-3 rounded hover:bg-indigo-700 transition"
                >
                  Proceed to Checkout
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </ClientOnly>
  );
}