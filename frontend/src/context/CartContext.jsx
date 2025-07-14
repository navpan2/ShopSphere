"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
} from "react";
import API from "@/services/api";
import toast from "react-hot-toast";

const CartContext = createContext();

export const useCart = () => {
  const context = useContext(CartContext);
  if (!context) {
    throw new Error("useCart must be used within CartProvider");
  }
  return context;
};

export const CartProvider = ({ children }) => {
  const [cart, setCart] = useState([]);
  const [loading, setLoading] = useState(false);

  const fetchCart = useCallback(async () => {
    try {
      const token = localStorage.getItem("token");
      if (!token) {
        setCart([]);
        return;
      }

      const res = await API.get("/cart");
      setCart(res.data);
    } catch (err) {
      console.error("Failed to fetch cart:", err);
      if (err.response?.status === 401) {
        localStorage.removeItem("token");
        localStorage.removeItem("user");
        setCart([]);
      }
    }
  }, []);

  useEffect(() => {
    fetchCart();
  }, [fetchCart]);

  const addToCart = async (productId, quantity) => {
    setLoading(true);
    try {
      const res = await API.post("/cart/add", {
        product_id: productId,
        quantity,
      });

      if (res.data) {
        toast.success("Added to cart!");
        await fetchCart(); // Refresh cart
      }
    } catch (err) {
      const message = err.response?.data?.detail || "Failed to add to cart";
      throw new Error(message);
    } finally {
      setLoading(false);
    }
  };

  const updateCartItem = async (productId, quantity) => {
    if (quantity <= 0) {
      return removeFromCart(productId);
    }

    setLoading(true);
    try {
      await API.patch(`/cart/update/${productId}?quantity=${quantity}`);
      await fetchCart(); // Refresh cart
    } catch (err) {
      const message = err.response?.data?.detail || "Failed to update cart";
      throw new Error(message);
    } finally {
      setLoading(false);
    }
  };

  const removeFromCart = async (productId) => {
    setLoading(true);
    try {
      await API.delete(`/cart/remove/${productId}`);
      toast.success("Removed from cart");
      await fetchCart(); // Refresh cart
    } catch (err) {
      const message =
        err.response?.data?.detail || "Failed to remove from cart";
      throw new Error(message);
    } finally {
      setLoading(false);
    }
  };

  const clearCart = async () => {
    setLoading(true);
    try {
      await API.delete("/cart/clear");
      setCart([]);
    } catch (err) {
      throw new Error("Failed to clear cart");
    } finally {
      setLoading(false);
    }
  };

  return (
    <CartContext.Provider
      value={{
        cart,
        loading,
        fetchCart,
        addToCart,
        updateCartItem,
        removeFromCart,
        clearCart,
      }}
    >
      {children}
    </CartContext.Provider>
  );
};
