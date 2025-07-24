/** @type {import('next').NextConfig} */
const nextConfig = {
  // Railway optimization
  output: "standalone",

  // Use Railway's PORT environment variable
  env: {
    PORT: 3000,
    NEXT_PUBLIC_API_URL:
      process.env.NEXT_PUBLIC_API_URL || "http://localhost:8001",
  },

  // Image optimization
  images: {
    domains: ["images.unsplash.com", "plus.unsplash.com"],
  },

  // Railway-specific config
  experimental: {
    outputFileTracingRoot: undefined,
  },
};

export default nextConfig;
