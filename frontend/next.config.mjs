// ShopSphere/frontend/next.config.mjs (Updated with your existing config)
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable standalone output for Docker
  output: "standalone",

  // API proxy configuration
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: "http://backend:8001/:path*", // Proxy to Backend
      },
    ];
  },

  // Environment variables
  env: {
    NEXT_PUBLIC_API_URL:
      process.env.NEXT_PUBLIC_API_URL || "http://localhost:8001",
  },

  // Image optimization (merged with your existing domains)
  images: {
    domains: ["images.unsplash.com", "plus.unsplash.com", "localhost"],
  },

  // Headers for security
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
        ],
      },
    ];
  },
};

export default nextConfig;
