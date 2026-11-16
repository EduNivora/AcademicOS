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
});
