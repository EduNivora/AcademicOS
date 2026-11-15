import { defineConfig } from "@neon/config/v1";

export default defineConfig({
  auth: true,
  functions: {
    notices: {
      name: "EduNivora Notices API",
      source: "backend/neon/dist/notices.mjs",
    },
  },
  branch: () => ({
    functions: {
      notices: {
        runtime: "nodejs24",
      },
    },
  }),
});
