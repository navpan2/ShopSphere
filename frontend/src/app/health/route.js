export async function GET() {
  return Response.json({
    status: "healthy",
    service: "shopsphere-frontend",
    port: 3000,
    timestamp: new Date().toISOString(),
  });
}
