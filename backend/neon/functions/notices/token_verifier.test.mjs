import test from "node:test";
import assert from "node:assert/strict";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from "jose";
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

test("cryptographically rejects malformed, expired, wrong-issuer and wrong-audience JWTs", async () => {
  const { privateKey, publicKey } = await generateKeyPair("EdDSA");
  const jwk = await exportJWK(publicKey);
  jwk.kid = "edunivora-test-key";
  jwk.alg = "EdDSA";
  jwk.use = "sig";
  const localJwks = createLocalJWKSet({ keys: [jwk] });
  const issuer = "https://auth.example.test";
  const subject = "9c6d51f0-78b9-4b3e-8a3b-5cb08d0a29a0";
  const now = Math.floor(Date.now() / 1000);
  const verifyIdentity = createNeonIdentityVerifier({
    authBaseUrl: issuer + "/edunivora/auth",
    jwksUrl: issuer + "/edunivora/auth/.well-known/jwks.json",
    createRemoteJWKSetFn: () => localJwks,
  });

  const sign = ({ iss = issuer, aud = issuer, iat = now, exp = now + 3600 } = {}) =>
    new SignJWT({})
      .setProtectedHeader({ alg: "EdDSA", kid: "edunivora-test-key" })
      .setSubject(subject)
      .setIssuer(iss)
      .setAudience(aud)
      .setIssuedAt(iat)
      .setExpirationTime(exp)
      .sign(privateKey);

  const valid = await verifyIdentity(await sign());
  assert.equal(valid.sub, subject);
  await assert.rejects(() => verifyIdentity("not-a-jwt"));
  await assert.rejects(() => sign({ iat: now - 3600, exp: now - 1800 }).then(verifyIdentity));
  await assert.rejects(() => sign({ iss: "https://wrong-issuer.example.test" }).then(verifyIdentity));
  await assert.rejects(() => sign({ aud: "https://wrong-audience.example.test" }).then(verifyIdentity));
});
