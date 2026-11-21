import { Pool } from "pg";
import { attachDatabasePool } from "@neon/functions";
import { createAiHandler, createNeonIdentityVerifier } from "./app.mjs";

const required = ["DATABASE_URL", "NEON_AUTH_BASE_URL", "NEON_AUTH_JWKS_URL"];
for (const key of required) {
  if (!process.env[key]) throw new Error(`Missing required runtime variable: ${key}`);
}

const databaseUrl = new URL(process.env.DATABASE_URL);
databaseUrl.searchParams.set("sslmode", "verify-full");

const pool = new Pool({
  connectionString: databaseUrl.toString(),
  max: 5,
  idleTimeoutMillis: 10_000,
  connectionTimeoutMillis: 5_000,
});
attachDatabasePool(pool);

const verifyIdentity = createNeonIdentityVerifier({
  authBaseUrl: process.env.NEON_AUTH_BASE_URL,
  jwksUrl: process.env.NEON_AUTH_JWKS_URL,
});
const allowedOrigins = (process.env.APP_ORIGINS ?? "").split(",").map((x) => x.trim()).filter(Boolean);

export default createAiHandler({
  verifyIdentity,
  apiKey: process.env.GEMINI_API_KEY,
  pool,
  allowedOrigins,
});
