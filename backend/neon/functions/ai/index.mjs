import { createAiHandler, createNeonIdentityVerifier } from "./app.mjs";
for (const key of ["NEON_AUTH_BASE_URL", "NEON_AUTH_JWKS_URL"]) {
  if (!process.env[key]) throw new Error(`Missing required runtime variable: ${key}`);
}
const verifyIdentity = createNeonIdentityVerifier({
  authBaseUrl: process.env.NEON_AUTH_BASE_URL,
  jwksUrl: process.env.NEON_AUTH_JWKS_URL,
});
const allowedOrigins = (process.env.APP_ORIGINS ?? "").split(",").map((x) => x.trim()).filter(Boolean);
export default createAiHandler({
  verifyIdentity,
  apiKey: process.env.GEMINI_API_KEY,
  allowedOrigins,
});
