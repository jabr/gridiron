/**
 * Counter Service - Cloudflare Workers compatible
 *
 * A virtual object service demonstrating durable state in Gridiron.
 * Each counter is identified by a unique key and maintains its state
 * across invocations.
 *
 * Handlers:
 * - get() -> number: Get current count
 * - increment() -> number: Increment by 1
 * - add(n: number) -> number: Add n to counter
 * - reset(): Reset to 0
 */

import * as restate from "@restatedev/restate-sdk-cloudflare-workers/fetch";

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

    async add(ctx, value: number) {
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

export default {
  fetch: restate.createEndpointHandler({ services: [counter] })
};
