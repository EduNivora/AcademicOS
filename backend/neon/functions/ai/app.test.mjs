import test from "node:test";
import assert from "node:assert/strict";
import { createAiApp } from "./app.mjs";

const validIdentity = { sub: "9c6d51f0-78b9-4b3e-8a3b-5cb08d0a29a0" };

function makeApp({ verifyIdentity, fetchImpl } = {}) {
  return createAiApp({
    verifyIdentity: verifyIdentity ?? (async (token) => token === "valid" ? validIdentity : null),
    apiKey: "test-api-key-not-a-real-secret",
    allowedOrigins: ["https://app.example.test"],
    fetchImpl: fetchImpl ?? (async () => new Response(JSON.stringify({
      steps: [{ type: "model_output", content: [{ type: "text", text: "إجابة اختبارية" }] }],
      usage: { total_tokens: 12 },
    }), { status: 200, headers: { "Content-Type": "application/json" } })),
  });
}

test("health endpoint reports AI service availability without exposing configuration", async () => {
  const response = await makeApp().request("/health");
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true, service: "edunivora-ai" });
});

test("chat endpoint requires a bearer token", async () => {
  const response = await makeApp().request("/v1/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: "اشرح التفاضل" }),
  });
  assert.equal(response.status, 401);
});

test("chat endpoint rejects invalid identity tokens", async () => {
  const response = await makeApp().request("/v1/chat", {
    method: "POST",
    headers: { Authorization: "Bearer invalid", "Content-Type": "application/json" },
    body: JSON.stringify({ message: "اشرح التفاضل" }),
  });
  assert.equal(response.status, 401);
});

test("valid authenticated request returns Gemini answer", async () => {
  let requestOptions;
  const app = makeApp({
    fetchImpl: async (_url, options) => {
      requestOptions = options;
      return new Response(JSON.stringify({
        steps: [{ type: "model_output", content: [{ type: "text", text: "شرح مبسط." }] }],
      }), { status: 200 });
    },
  });
  const response = await app.request("/v1/chat", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ message: "اشرح التفاضل" }),
  });
  assert.equal(response.status, 200);
  const data = await response.json();
  assert.equal(data.answer, "شرح مبسط.");
  assert.equal(data.model, "gemini-3.8-flash");
  assert.equal(requestOptions.headers["x-goog-api-key"], "test-api-key-not-a-real-secret");
});

test("academic context is forwarded as a separate data-only message", async () => {
  let payload;
  const app = makeApp({
    fetchImpl: async (_url, options) => {
      payload = JSON.parse(options.body);
      return new Response(JSON.stringify({
        steps: [{ type: "model_output", content: [{ type: "text", text: "تم التحليل." }] }],
      }), { status: 200 });
    },
  });
  const response = await app.request("/v1/chat", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ message: "ما أولويتي؟", context: "لدي مهمتان واختبار غدًا." }),
  });
  assert.equal(response.status, 200);
  assert.match(payload.input[0].content, /بيانات أكاديمية مرجعية/);
  assert.equal(payload.input[1].content, "ما أولويتي؟");
  assert.equal(payload.store, false);
  assert.equal(payload.model, "gemini-3.8-flash");
});

test("oversized user messages are rejected before provider invocation", async () => {
  let called = false;
  const app = makeApp({ fetchImpl: async () => { called = true; return new Response("{}"); } });
  const response = await app.request("/v1/chat", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ message: "x".repeat(12_001) }),
  });
  assert.equal(response.status, 400);
  assert.equal(called, false);
});

test("provider rate limits are mapped to a safe client error", async () => {
  const app = makeApp({ fetchImpl: async () => new Response("private provider details", { status: 429 }) });
  const response = await app.request("/v1/chat", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ message: "اشرح التفاضل" }),
  });
  assert.equal(response.status, 429);
  assert.doesNotMatch(await response.text(), /private provider details/);
});

test("provider configuration errors never disclose provider response bodies", async () => {
  const app = makeApp({ fetchImpl: async () => new Response("secret diagnostic", { status: 403 }) });
  const response = await app.request("/v1/chat", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ message: "اشرح التفاضل" }),
  });
  assert.equal(response.status, 503);
  assert.doesNotMatch(await response.text(), /secret diagnostic/);
});

test("CORS only reflects configured application origins", async () => {
  const app = makeApp();
  const allowed = await app.request("/health", { headers: { Origin: "https://app.example.test" } });
  const denied = await app.request("/health", { headers: { Origin: "https://evil.example.test" } });
  assert.equal(allowed.headers.get("Access-Control-Allow-Origin"), "https://app.example.test");
  assert.equal(denied.headers.get("Access-Control-Allow-Origin"), null);
});
