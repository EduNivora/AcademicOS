import { Pool } from "pg";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { attachDatabasePool } from "@neon/functions";
import { createApp } from "./app.mjs";

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

const jwks = createRemoteJWKSet(new URL(process.env.NEON_AUTH_JWKS_URL));
const verifyIdentity = async (token) => {
  const { payload } = await jwtVerify(token, jwks, {
    issuer: process.env.NEON_AUTH_BASE_URL,
    algorithms: ["EdDSA"],
  });
  return payload;
};

const allowedOrigins = (process.env.APP_ORIGINS ?? "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

export default createApp({ pool, verifyIdentity, allowedOrigins });
