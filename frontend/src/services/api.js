// src/services/api.js

import axios from "axios";
import toast from "react-hot-toast";

// ✅ Create Axios instance
const API = axios.create({
  baseURL: "http://localhost:8001", // ⬅️ Update if your backend runs elsewhere
});

// ✅ Attach Bearer token from localStorage (client-only)
API.interceptors.request.use(
  (config) => {
    if (typeof window !== "undefined") {
      const token = localStorage.getItem("token");
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// ✅ Global 401 handler (token expired, invalid, or missing)
API.interceptors.response.use(
  (response) => response,
  (error) => {
    if (typeof window !== "undefined" && error.response?.status === 401) {
      // ✅ Clear session
      localStorage.removeItem("token");
      localStorage.removeItem("user");

      // ✅ Show toast once
      if (!window.__hasShownTokenExpireToast) {
        toast.error("Session expired. Please log in again.");
        window.__hasShownTokenExpireToast = true;

        // Reset the flag after 3 seconds so toast can reappear later if needed
        setTimeout(() => {
          window.__hasShownTokenExpireToast = false;
        }, 3000);
      }

      // ✅ Redirect to login page
      window.location.href = "/login";
    }

    return Promise.reject(error);
  }
);

export default API;
