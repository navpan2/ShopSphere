export async function GET() {
  return Response.json({
    status: "healthy",
    service: "shopsphere-frontend",
    port: process.env.PORT || 3000,
    timestamp: new Date().toISOString(),
  });
}
