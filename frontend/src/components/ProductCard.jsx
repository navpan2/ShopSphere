"use client";
import Image from "next/image";
import { useCart } from "@/context/CartContext";

export default function ProductCard({ product }) {
  const { addToCart } = useCart();

  const handleAddToCart = () => {
    addToCart(product.id, 1);
  };

  return (
    <div className="bg-white rounded-xl shadow-lg hover:shadow-2xl transition duration-300 ease-in-out p-4 flex flex-col items-center">
      <div className="w-full h-48 relative mb-4">
        <Image
          src={product.image_url || "/placeholder.png"}
          alt={product.name}
          fill
          className="rounded-md object-cover"
        />
      </div>
      <h2 className="text-lg font-semibold text-gray-800 text-center">
        {product.name}
      </h2>
      <p className="text-gray-600 text-sm mt-1 text-center line-clamp-2">
        {product.description}
      </p>
      <p className="text-indigo-600 font-bold text-lg mt-2">₹{product.price}</p>

      {product.stock > 0 ? (
        <button
          className="mt-3 w-full bg-indigo-600 text-white py-2 rounded hover:bg-indigo-700 transition"
          onClick={() => addToCart(product.id, 1)}
        >
          Add to Cart
        </button>
      ) : (
        <button
          className="mt-3 w-full bg-gray-400 text-white py-2 rounded cursor-not-allowed"
          disabled
        >
          Out of Stock
        </button>
      )}
    </div>
  );
}
