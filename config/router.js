// Gridiron Router - Simple path-based router
// Routes requests based on path prefix to the appropriate service
// Each service handles its own /discover independently

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    
    console.log(`Router received request: ${pathname}`);
    
    // Extract the service path prefix from the URL
    // Format: /{service-build-id}/... (e.g., /counter-1.0.0-1234/invoke/Counter/get)
    const pathParts = pathname.split('/').filter(p => p.length > 0);
    
    if (pathParts.length === 0) {
      return new Response(JSON.stringify({
        error: "No service path specified. Expected: /{service-build-id}/..."
      }), { 
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    // First path segment is the service build ID
    const servicePath = pathParts[0];
    
    console.log(`Looking for service: ${servicePath}`);
    console.log(`Available bindings: ${Object.keys(env).filter(k => env[k] && typeof env[k].fetch === 'function').join(', ')}`);
    
    // Find the service binding
    // Bindings are named with the full build ID (e.g., counter-1.0.0-1234)
    const serviceBinding = env[servicePath];
    
    if (!serviceBinding || !serviceBinding.fetch) {
      const available = Object.keys(env).filter(k => env[k] && typeof env[k].fetch === 'function');
      return new Response(JSON.stringify({
        error: `Service '${servicePath}' not found. Available: ${available.join(', ')}`
      }), { 
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    // Forward the request to the service
    // The service receives the full path and handles its own /discover
    try {
      console.log(`Routing to service: ${servicePath}`);
      return await serviceBinding.fetch(request);
    } catch (e) {
      console.error(`Error routing to ${servicePath}:`, e);
      return new Response(JSON.stringify({
        error: `Error calling service '${servicePath}': ${e.message}`
      }), { 
        status: 500,
        headers: { "Content-Type": "application/json" }
      });
    }
  }
};
