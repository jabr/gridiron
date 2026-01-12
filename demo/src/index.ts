/**
 * Gridiron Demo Service - Cloudflare Workers compatible
 * Uses @restatedev/restate-sdk-cloudflare-workers
 */

import * as restate from "@restatedev/restate-sdk-cloudflare-workers/fetch";

// Counter service - demonstrates durable state with virtual objects
const counter = restate.object({
  name: "Counter",
  handlers: {
    async get(ctx) {
      const count = (await ctx.get("count")) ?? 0;
      ctx.console.log(`Counter ${ctx.key}: current count is ${count}`);
      return count;
    },

    async increment(ctx) {
      const count = (await ctx.get("count")) ?? 0;
      const newCount = count + 1;
      ctx.set("count", newCount);
      ctx.console.log(`Counter ${ctx.key}: incremented to ${newCount}`);
      return newCount;
    },

    async add(ctx, value) {
      const count = (await ctx.get("count")) ?? 0;
      const newCount = count + value;
      ctx.set("count", newCount);
      ctx.console.log(`Counter ${ctx.key}: added ${value}, now ${newCount}`);
      return newCount;
    },

    async reset(ctx) {
      ctx.clear("count");
      ctx.console.log(`Counter ${ctx.key}: reset to 0`);
    },
  },
});

// Greeter service - demonstrates simple request/response
const greeter = restate.service({
  name: "Greeter",
  handlers: {
    async greet(ctx, name) {
      ctx.console.log(`Greeting: ${name}`);
      return `Hello, ${name}! Welcome to Gridiron.`;
    },

    async ping(ctx) {
      return "pong";
    },
  },
});

// Export the Restate handler for Cloudflare Workers / workerd
export default {
  fetch: restate.createEndpointHandler({ services: [counter, greeter] })
};
