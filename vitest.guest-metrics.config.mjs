import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: {
        configPath: "./backend/neon/guest-metrics-worker/wrangler.jsonc",
      },
    }),
  ],
  test: {
    // The backend Node:test suite is run separately with node --test.
    // This config must execute only the Durable Object runtime suite.
    include: ["backend/neon/guest-metrics-worker/worker.runtime.test.mjs"],
  },
});
