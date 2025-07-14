"use client";

import { useEffect, useState } from "react";
import API from "@/services/api";
import toast from "react-hot-toast";
import Loader from "@/components/Loader";
import ClientOnly from "@/components/ClientOnly";
import { useRouter } from "next/navigation";

export default function ManageProductsPage() {
  const [products, setProducts] = useState([]);
  const [form, setForm] = useState({
    name: "",
    description: "",
    price: "",
    image_url: "",
    stock: "",
  });
  const [editId, setEditId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [pageLoading, setPageLoading] = useState(true);
  const [deleteLoading, setDeleteLoading] = useState({});
  const router = useRouter();

  useEffect(() => {
    const user = JSON.parse(localStorage.getItem("user") || "{}");
    if (!user || !user.is_admin) {
      toast.error("Admins only!");
      router.push("/");
    } else {
      fetchProducts();
    }
  }, [router]);

  const fetchProducts = async () => {
    try {
      const res = await API.get("/products");
      setProducts(res.data);
    } catch (err) {
      toast.error("Failed to load products");
    } finally {
      setPageLoading(false);
    }
  };

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      price: parseFloat(form.price),
      stock: parseInt(form.stock),
    };

    try {
      setLoading(true);
      if (editId) {
        await API.put(`/products/${editId}`, payload);
        toast.success("Product updated");
      } else {
        await API.post("/products", payload);
        toast.success("Product added");
      }
      setForm({
        name: "",
        description: "",
        price: "",
        image_url: "",
        stock: "",
      });
      setEditId(null);
      await fetchProducts();
    } catch (err) {
      toast.error("Save failed");
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (product) => {
    setEditId(product.id);
    setForm({
      name: product.name,
      description: product.description,
      price: product.price,
      image_url: product.image_url,
      stock: product.stock,
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Are you sure you want to delete this product?"))
      return;

    setDeleteLoading((prev) => ({ ...prev, [id]: true }));
    try {
      await API.delete(`/products/${id}`);
      toast.success("Product deleted");
      await fetchProducts();
    } catch (err) {
      toast.error("Delete failed");
    } finally {
      setDeleteLoading((prev) => ({ ...prev, [id]: false }));
    }
  };

  return (
    <ClientOnly>
      <div className="min-h-screen bg-gray-900 text-white py-10 px-6">
        <h1 className="text-3xl font-bold text-center text-indigo-400 mb-6">
          🛠️ Admin - Manage Products
        </h1>

        {/* Form Section */}
        <form
          onSubmit={handleSubmit}
          className="bg-gray-800 rounded-lg p-6 max-w-3xl mx-auto mb-10 space-y-4 shadow-md"
        >
          <h2 className="text-xl font-semibold">
            {editId ? "✏️ Edit Product" : "➕ Add New Product"}
          </h2>

          <input
            type="text"
            name="name"
            value={form.name}
            onChange={handleChange}
            placeholder="Product Name"
            required
            disabled={loading}
            className="w-full bg-gray-700 text-white border border-gray-600 px-4 py-2 rounded placeholder-gray-400 disabled:opacity-50"
          />
          <textarea
            name="description"
            value={form.description}
            onChange={handleChange}
            placeholder="Description"
            required
            disabled={loading}
            className="w-full bg-gray-700 text-white border border-gray-600 px-4 py-2 rounded placeholder-gray-400 disabled:opacity-50"
          />
          <input
            type="number"
            name="price"
            value={form.price}
            onChange={handleChange}
            placeholder="Price"
            required
            disabled={loading}
            className="w-full bg-gray-700 text-white border border-gray-600 px-4 py-2 rounded placeholder-gray-400 disabled:opacity-50"
          />
          <input
            type="text"
            name="image_url"
            value={form.image_url}
            onChange={handleChange}
            placeholder="Image URL"
            disabled={loading}
            className="w-full bg-gray-700 text-white border border-gray-600 px-4 py-2 rounded placeholder-gray-400 disabled:opacity-50"
          />
          <input
            type="number"
            name="stock"
            value={form.stock}
            onChange={handleChange}
            placeholder="Stock"
            required
            disabled={loading}
            className="w-full bg-gray-700 text-white border border-gray-600 px-4 py-2 rounded placeholder-gray-400 disabled:opacity-50"
          />

          <div className="flex justify-between items-center">
            <button
              type="submit"
              disabled={loading}
              className="bg-indigo-600 text-white px-6 py-2 rounded hover:bg-indigo-700 transition disabled:opacity-50 flex items-center"
            >
              {loading ? (
                <Loader size="sm" />
              ) : editId ? (
                "Update Product"
              ) : (
                "Add Product"
              )}
            </button>
            {editId && (
              <button
                type="button"
                onClick={() => {
                  setEditId(null);
                  setForm({
                    name: "",
                    description: "",
                    price: "",
                    image_url: "",
                    stock: "",
                  });
                }}
                className="text-red-400 underline text-sm"
              >
                Cancel Edit
              </button>
            )}
          </div>
        </form>

        {/* Product List */}
        <h2 className="text-xl font-bold text-gray-300 mb-4">
          📄 All Products
        </h2>

        {pageLoading ? (
          <div className="flex justify-center mt-10">
            <Loader size="lg" text="Loading products..." />
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
            {products.map((product) => (
              <div
                key={product.id}
                className="bg-[#1f2937] rounded-xl shadow-md p-4 transition duration-300 hover:shadow-lg"
              >
                <div className="h-48 w-full rounded-lg overflow-hidden mb-4">
                  <img
                    src={product.image_url || "/placeholder.png"}
                    alt={product.name}
                    className="w-full h-full object-cover transform hover:scale-105 transition duration-300"
                  />
                </div>

                <h3 className="text-lg font-bold text-white">{product.name}</h3>
                <p className="text-sm text-gray-400 mt-1">
                  {product.description}
                </p>

                <p className="text-indigo-400 font-semibold text-lg mt-2">
                  ₹{product.price}
                </p>
                <p className="text-sm text-gray-400">Stock: {product.stock}</p>

                <div className="flex gap-3 mt-3">
                  <button
                    onClick={() => handleEdit(product)}
                    className="text-sm bg-yellow-500 text-black px-3 py-1 rounded hover:bg-yellow-600"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => handleDelete(product.id)}
                    disabled={deleteLoading[product.id]}
                    className="text-sm bg-red-600 text-white px-3 py-1 rounded hover:bg-red-700 disabled:opacity-50 min-w-[60px]"
                  >
                    {deleteLoading[product.id] ? "..." : "Delete"}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </ClientOnly>
  );
}
