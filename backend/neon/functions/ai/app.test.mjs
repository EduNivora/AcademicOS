import test from "node:test";
import assert from "node:assert/strict";
import { createAiHandler } from "./app.mjs";
const token = "valid";
const identity = { sub: "user-123" };
const make = ({ apiKey = "test-api-key-not-real", fetchImpl, verifyIdentity } = {}) =>
  createAiHandler({
    verifyIdentity: verifyIdentity ?? (async (value) => value === token ? identity : null),
    apiKey,
    allowedOrigins: ["https://app.example.test"],
    fetchImpl: fetchImpl ?? (async () => Response.json({
      steps: [{ type: "model_output", content: [{ type: "text", text: "جواب اختباري" }] }],
      usage: { total_tokens: 10 },
    })),
  });
const request = (message, { bearer = token, context, origin } = {}) =>
  new Request("https://unit.test/v1/chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(bearer ? { Authorization: "Bearer " + bearer } : {}),
      ...(origin ? { Origin: origin } : {}),
    },
    body: JSON.stringify({ message, ...(context === undefined ? {} : { context }) }),
  });

test("health route", async () => {
  const response = await make()(new Request("https://unit.test/health"));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).service, "edunivora-ai");
});
test("authentication is required", async () => {
  assert.equal((await make()(request("سؤال", { bearer: null }))).status, 401);
});
test("invalid bearer token is rejected", async () => {
  assert.equal((await make()(request("سؤال", { bearer: "bad" }))).status, 401);
});
test("valid request calls Gemini Interactions API", async () => {
  let sent;
  const response = await make({ fetchImpl: async (url, options) => {
    sent = { url, options };
    return Response.json({ steps: [{ type: "model_output", content: [{ type: "text", text: "شرح." }] }] });
  }})(request("اشرح"));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).answer, "شرح.");
  assert.equal(sent.url, "https://generativelanguage.googleapis.com/v1beta/interactions");
  assert.equal(JSON.parse(sent.options.body).model, "gemini-3.8-flash");
  assert.equal(JSON.parse(sent.options.body).store, false);
});
test("academic context is bounded and forwarded separately", async () => {
  let payload;
  const response = await make({ fetchImpl: async (_url, options) => {
    payload = JSON.parse(options.body);
    return Response.json({ steps: [{ type: "model_output", content: [{ type: "text", text: "تمام" }] }] });
  }})(request("ما أولويتي؟", { context: "لدي اختبار غدًا" }));
  assert.equal(response.status, 200);
  assert.match(payload.input[0].content, /بيانات أكاديمية/);
  assert.equal(payload.input[1].content, "ما أولويتي؟");
});
test("message size is validated before provider call", async () => {
  let called = false;
  const response = await make({ fetchImpl: async () => { called = true; return Response.json({}); } })(request("x".repeat(12001)));
  assert.equal(response.status, 400);
  assert.equal(called, false);
});
test("provider diagnostics are not exposed", async () => {
  const response = await make({ fetchImpl: async () => new Response("secret detail", { status: 403 }) })(request("سؤال"));
  assert.equal(response.status, 503);
  assert.doesNotMatch(await response.text(), /secret detail/);
});
test("missing Gemini key fails closed", async () => {
  const response = await make({ apiKey: "" })(request("سؤال"));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "ai_not_configured");
});
test("CORS only allows configured origins", async () => {
  const handler = make();
  const allowed = await handler(new Request("https://unit.test/health", { headers: { Origin: "https://app.example.test" } }));
  const denied = await handler(new Request("https://unit.test/health", { headers: { Origin: "https://evil.test" } }));
  assert.equal(allowed.headers.get("Access-Control-Allow-Origin"), "https://app.example.test");
  assert.equal(denied.headers.get("Access-Control-Allow-Origin"), null);
});
