/**
 * Greeter Service - Cloudflare Workers compatible
 * 
 * A simple request/response service demonstrating stateless handlers
 * in Gridiron. Useful for testing deployments and health checks.
 * 
 * Handlers:
 * - greet(name: string) -> string: Returns a personalized greeting
 * - ping() -> string: Health check, returns "pong"
 * - getVersion() -> object: Returns the service identifier
 */

import * as restate from "@restatedev/restate-sdk-cloudflare-workers/fetch";

const greeter = restate.service({
  name: "Greeter",
  handlers: {
    async greet(ctx, name: string) {
      const greeting = `Hello, ${name}! Welcome to Gridiron`;
      ctx.console.log(greeting);
      return greeting;
    },

    async ping(ctx) {
      ctx.console.log("Ping received");
      return "pong";
    },

    async getVersion(ctx) {
      ctx.console.log("Greeter version requested");
      return {
        service: "Greeter",
      };
    },
  },
});

export default {
  fetch: restate.createEndpointHandler({ services: [greeter] })
};
