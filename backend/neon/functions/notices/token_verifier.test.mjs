import test from "node:test";
import assert from "node:assert/strict";
import { createNeonIdentityVerifier } from "./token_verifier.mjs";

test("verifies Neon JWTs against the auth URL origin for issuer and audience", async () => {
  let receivedJwksUrl;
  let receivedToken;
  let receivedKeySet;
  let receivedOptions;
  const expectedPayload = {
    sub: "9c6d51f0-78b9-4b3e-8a3b-5cb08d0a29a0",
    iss: "https://ep-example.neonauth.aws.neon.tech",
    aud: "https://ep-example.neonauth.aws.neon.tech",
  };

  const verifyIdentity = createNeonIdentityVerifier({
    authBaseUrl: "https://ep-example.neonauth.aws.neon.tech/edunivora/auth",
    jwksUrl: "https://ep-example.neonauth.aws.neon.tech/edunivora/auth/.well-known/jwks.json",
    createRemoteJWKSetFn: (url) => {
      receivedJwksUrl = url.toString();
      return { keySet: true };
    },
    jwtVerifyFn: async (token, keySet, options) => {
      receivedToken = token;
      receivedKeySet = keySet;
      receivedOptions = options;
      return { payload: expectedPayload };
    },
  });

  const payload = await verifyIdentity("signed-jwt");

  assert.equal(receivedJwksUrl,
    "https://ep-example.neonauth.aws.neon.tech/edunivora/auth/.well-known/jwks.json");
  assert.equal(receivedToken, "signed-jwt");
  assert.deepEqual(receivedKeySet, { keySet: true });
  assert.deepEqual(receivedOptions, {
    issuer: "https://ep-example.neonauth.aws.neon.tech",
    audience: "https://ep-example.neonauth.aws.neon.tech",
    algorithms: ["EdDSA"],
  });
  assert.deepEqual(payload, expectedPayload);
});
