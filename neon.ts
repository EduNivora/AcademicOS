import { defineConfig } from "@neon/config/v1";

export default defineConfig({
  auth: true,
  functions: {
    notices: {
      name: "EduNivora Notices API",
      source: "backend/neon/functions/notices/index.mjs",
      externalPackages: ["pg", "@neon/functions"],
    },
    ai: {
      name: "EduNivora AI",
      source: "backend/neon/functions/ai/index.mjs",
      externalPackages: ["pg", "@neon/functions"],
      env: {
        GEMINI_API_KEY: {
          value: process.env.GEMINI_API_KEY,
          required: true,
        },
      },
    },
  },
  branch: () => ({
    functions: {
      notices: {
        runtime: "nodejs24",
      },
      ai: {
        runtime: "nodejs24",
      },
    },
  }),
});
