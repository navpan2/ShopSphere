/** @type {import('next').NextConfig} */
const nextConfig = {
  // Railway optimization
  output: process.env.NODE_ENV === "production" ? "standalone" : undefined,

  // Environment variables
  env: {
    NEXT_PUBLIC_API_URL:
      process.env.NEXT_PUBLIC_API_URL || "http://localhost:8001",
    RAILWAY_ENVIRONMENT: process.env.RAILWAY_ENVIRONMENT || "development",
  },

  // Optimize for Railway
  experimental: {
    outputFileTracingRoot: undefined, // Let Railway handle this
  },

  // Image optimization
  images: {
    domains: ["images.unsplash.com", "plus.unsplash.com"],
    unoptimized: process.env.NODE_ENV === "production", // Reduce build time
  },
};

export default nextConfig;
