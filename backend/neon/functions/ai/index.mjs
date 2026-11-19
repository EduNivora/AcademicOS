import { Hono } from "hono";
import { cors } from "hono/cors";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { createAiApp } from "./app.mjs";

const required = ["NEON_AUTH_BASE_URL", "NEON_AUTH_JWKS_URL", "GEMINI_API_KEY"];
for (const key of required) {
  if (!process.env[key]) throw new Error(`Missing required runtime variable: ${key}`);
}

const issuer = new URL(process.env.NEON_AUTH_BASE_URL).origin;
const jwks = createRemoteJWKSet(new URL(process.env.NEON_AUTH_JWKS_URL));
const verifyIdentity = async (token) => {
  const { payload } = await jwtVerify(token, jwks, {
    issuer,
    audience: issuer,
    algorithms: ["EdDSA"],
  });
  return payload;
};

const allowedOrigins = (process.env.APP_ORIGINS ?? "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

export default createAiApp({
  verifyIdentity,
  apiKey: process.env.GEMINI_API_KEY,
  allowedOrigins,
  fetchImpl: fetch,
});
