import { createRemoteJWKSet, jwtVerify } from "jose";

/**
 * Creates a Neon Managed Auth JWT verifier.
 *
 * Neon Auth sets both iss and aud to the URL origin, not the full
 * branch auth URL path (for example, not the trailing /database/auth).
 */
export function createNeonIdentityVerifier({
  authBaseUrl,
  jwksUrl,
  createRemoteJWKSetFn = createRemoteJWKSet,
  jwtVerifyFn = jwtVerify,
}) {
  const issuer = new URL(authBaseUrl).origin;
  const jwks = createRemoteJWKSetFn(new URL(jwksUrl));

  return async (token) => {
    const { payload } = await jwtVerifyFn(token, jwks, {
      issuer,
      audience: issuer,
      algorithms: ["EdDSA"],
    });
    return payload;
  };
}
