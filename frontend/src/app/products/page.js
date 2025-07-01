"use client";

import { useEffect, useState } from "react";
import API from "@/services/api";
import Image from "next/image";
import { useCart } from "@/context/CartContext";
import toast from "react-hot-toast";

export default function ProductsPage() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const { cart, addToCart, updateCartItem } = useCart();

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (token) {
      fetchProducts();
    }
  }, []);
  

  const fetchProducts = async () => {
    try {
      const res = await API.get("/products");
      setProducts(res.data);
    } catch (err) {
      console.error("Error fetching products:", err);
    } finally {
      setLoading(false);
    }
  };

  const getQuantityInCart = (productId) => {
    const item = cart.find((c) => c.product.id === productId);
    return item ? item.quantity : 0;
  };

  const handleIncrease = (productId, stock) => {
    const currentQty = getQuantityInCart(productId);
    if (currentQty >= stock) {
      toast.error("Cannot add more than available stock!");
      return;
    }
    updateCartItem(productId, currentQty + 1);
  };

  const handleDecrease = (productId) => {
    const currentQty = getQuantityInCart(productId);
    updateCartItem(productId, currentQty - 1);
  };

  return (
    <div className="min-h-screen bg-gray-50 py-10 px-6">
      <h1 className="text-4xl font-bold text-center text-indigo-600 mb-10">
        🛒 Browse Our Products
      </h1>

      {loading ? (
        <div className="flex justify-center mt-20">
          <div className="w-12 h-12 border-4 border-dashed rounded-full animate-spin border-indigo-500"></div>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-8 max-w-7xl mx-auto">
          {products.map((product) => {
            const quantity = getQuantityInCart(product.id);
            const isMaxed = quantity >= product.stock;

            return (
              <div
                key={product.id}
                className="bg-white rounded-xl shadow hover:shadow-lg transition p-5 flex flex-col items-center"
              >
                <div className="w-full h-48 bg-gray-100 rounded-lg overflow-hidden mb-4">
                  <Image
                    src={product.image_url || "/placeholder.png"}
                    alt={product.name}
                    width={300}
                    height={300}
                    className="object-cover w-full h-full"
                  />
                </div>
                <h2 className="text-lg font-semibold text-gray-800 text-center">
                  {product.name}
                </h2>
                <p className="text-gray-600 text-sm mt-1 text-center">
                  {product.description}
                </p>
                <p className="text-indigo-600 font-bold text-lg mt-2">
                  ₹ {product.price}
                </p>

                {product.stock > 0 ? (
                  quantity > 0 ? (
                    <div className="flex items-center gap-3 mt-4">
                      <button
                        className="px-3 py-1 bg-indigo-600 text-white rounded hover:bg-indigo-700"
                        onClick={() => handleDecrease(product.id)}
                      >
                        −
                      </button>
                      <span className="text-lg font-semibold text-gray-800">
                        {quantity}
                      </span>
                      <button
                        className={`px-3 py-1 rounded text-white ${
                          isMaxed
                            ? "bg-gray-400 cursor-not-allowed"
                            : "bg-indigo-600 hover:bg-indigo-700"
                        }`}
                        onClick={() =>
                          handleIncrease(product.id, product.stock)
                        }
                        disabled={isMaxed}
                      >
                        +
                      </button>
                    </div>
                  ) : (
                    <button
                      className="mt-4 bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 transition"
                      onClick={() => addToCart(product.id, 1)}
                    >
                      Add to Cart
                    </button>
                  )
                ) : (
                  <button
                    className="mt-4 bg-gray-400 text-white px-4 py-2 rounded cursor-not-allowed"
                    disabled
                  >
                    Out of Stock
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
