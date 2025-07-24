// Create this file: frontend/src/app/health/route.js
export async function GET() {
  return Response.json({
    status: "healthy",
    service: "shopsphere-frontend",
    timestamp: new Date().toISOString(),
  });
}
