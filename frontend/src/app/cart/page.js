"use client";

import { useEffect, useState } from "react";
import { useCart } from "@/context/CartContext";
import Image from "next/image";
import toast from "react-hot-toast";

export default function CartPage() {
  const { cart, updateCartItem, removeFromCart } = useCart();
  const [removingId, setRemovingId] = useState(null);

  const handleUpdate = (productId, newQty, stock) => {
    if (newQty > stock) {
      toast.error("Cannot add more than available stock.");
      return;
    }
    updateCartItem(productId, newQty);
  };

  const handleRemove = async (productId) => {
    setRemovingId(productId);
    await removeFromCart(productId);
    setRemovingId(null);
  };

  const getTotal = () =>
    cart.reduce((total, item) => total + item.quantity * item.product.price, 0);

  return (
    <div className="min-h-screen bg-gray-50 px-6 py-10">
      <h1 className="text-3xl font-bold text-center mb-8 text-indigo-700">
        🛍️ Your Shopping Cart
      </h1>

      {cart.length === 0 ? (
        <p className="text-center text-gray-500 mt-20 text-lg">
          Your cart is empty.
        </p>
      ) : (
        <div className="max-w-4xl mx-auto space-y-6">
          {cart.map(({ id, product, quantity }) => (
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
                  ₹{product.price} × {quantity} = ₹{product.price * quantity}
                </p>

                <div className="flex items-center mt-2 space-x-2">
                  <button
                    className="px-3 py-1 bg-indigo-600 text-white rounded hover:bg-indigo-700 disabled:opacity-50"
                    onClick={() =>
                      handleUpdate(product.id, quantity - 1, product.stock)
                    }
                    disabled={quantity <= 1}
                  >
                    −
                  </button>
                  <span className="px-3 text-gray-800">{quantity}</span>
                  <button
                    className="px-3 py-1 bg-indigo-600 text-white rounded hover:bg-indigo-700 disabled:opacity-50"
                    onClick={() =>
                      handleUpdate(product.id, quantity + 1, product.stock)
                    }
                    disabled={quantity >= product.stock}
                  >
                    +
                  </button>
                </div>
              </div>

              <button
                onClick={() => handleRemove(product.id)}
                disabled={removingId === product.id}
                className="absolute top-2 right-2 text-sm bg-red-500 text-white px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition"
              >
                {removingId === product.id ? "Removing..." : "Remove"}
              </button>
            </div>
          ))}

          <div className="text-right text-xl font-semibold text-gray-700 mt-6">
            Total: ₹ {getTotal()}
          </div>
        </div>
      )}
    </div>
  );
}
