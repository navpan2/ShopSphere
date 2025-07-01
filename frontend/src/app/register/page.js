"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import API from "@/services/api";
import NProgress from "nprogress";

export default function RegisterPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isAdmin, setIsAdmin] = useState(false);
  const [err, setErr] = useState("");
  const router = useRouter();
  const [adminCode, setAdminCode] = useState("");


  const handleRegister = async (e) => {
    e.preventDefault();
    NProgress.start();
    try {
      await API.post("/auth/register", {
        email,
        password,
        is_admin: isAdmin,
        admin_code: isAdmin ? adminCode : undefined,
      });
      setErr("");
      router.push("/login");
    } catch (err) {
      setErr(err.response?.data?.detail || "Registration failed");
    } finally {
      NProgress.done();
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-r from-rose-400 via-fuchsia-500 to-indigo-500 p-6">
      <form
        onSubmit={handleRegister}
        className="bg-white p-10 rounded-xl shadow-2xl w-full max-w-md"
      >
        <h2 className="text-3xl font-bold mb-6 text-center text-gray-800">
          📝 Register
        </h2>

        <div className="space-y-4">
          <div>
            <label className="block text-sm text-gray-700 mb-1">
              Email Address
            </label>
            <input
              type="email"
              placeholder="you@example.com"
              className="w-full px-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-400 outline-none text-gray-800"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div>
            <label className="block text-sm text-gray-700 mb-1">Password</label>
            <input
              type="password"
              placeholder="Create a strong password"
              className="w-full px-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-400 outline-none text-gray-800"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <div className="flex items-center space-x-2">
            <input
              type="checkbox"
              id="admin"
              checked={isAdmin}
              onChange={(e) => setIsAdmin(e.target.checked)}
              className="w-4 h-4 text-indigo-600"
            />
            <label htmlFor="admin" className="text-sm text-gray-700">
              Register as Admin
            </label>
          </div>
          {isAdmin && (
            <div>
              <label className="block text-sm text-gray-700 mb-1">
                Admin Secret Code
              </label>
              <input
                type="text"
                placeholder="Enter secret code"
                className="w-full px-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-400 outline-none text-gray-800"
                value={adminCode}
                onChange={(e) => setAdminCode(e.target.value)}
                required
              />
            </div>
          )}

          {err && <p className="text-red-600 text-sm mt-1">{err}</p>}

          <button
            type="submit"
            className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-3 rounded-lg transition duration-200"
          >
            Register
          </button>
        </div>
      </form>
    </div>
  );
}
