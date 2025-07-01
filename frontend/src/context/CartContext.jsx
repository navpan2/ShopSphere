"use client";

import { createContext, useContext, useEffect, useState } from "react";
import axios from "@/utils/axiosInstance";
import toast from "react-hot-toast";

const CartContext = createContext();

export const useCart = () => useContext(CartContext);


export const CartProvider = ({ children }) => {
  const [cart, setCart] = useState([]);

  // Fetch the cart items on mount or refresh
  const fetchCart = async () => {
    try {
      const res = await axios.get("/cart/");
      setCart(res.data);
    } catch (err) {
      console.error("Error fetching cart", err);
    }
  };

  // Add to cart
  const addToCart = async (productId, quantity = 1) => {
    try {
      await axios.post("/cart/add", {
        product_id: productId,
        quantity,
      });
      toast.success("Added to cart!");
      fetchCart();
    } catch (err) {
      console.error("Add to cart error:", err);
    }
  };

  // Update item quantity in cart
  const updateCartItem = async (productId, quantity) => {
    try {
      if (quantity <= 0) {
        await removeFromCart(productId);
        toast.success("Item removed from cart");
      } else {
        await axios.patch(`/cart/update/${productId}?quantity=${quantity}`);
        toast.success("Cart updated");
      }
      fetchCart();
    } catch (err) {
      console.error("Update cart error:", err);
    }
  };

  // Remove item from cart
  const removeFromCart = async (productId) => {
    try {
      await axios.delete(`/cart/remove/${productId}`);
      await fetchCart();
    } catch (err) {
      console.error("Remove cart error:", err);
    }
  };

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (token) {
      fetchCart(); // ✅ only fetch if token exists
    }
  }, []);

  return (
    <CartContext.Provider
      value={{ cart, addToCart, updateCartItem, removeFromCart, fetchCart }}
    >
      {children}
    </CartContext.Provider>
  );
};
