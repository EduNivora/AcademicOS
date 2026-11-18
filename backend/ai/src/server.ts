import Fastify from 'fastify';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { config, loadSystemPrompt } from './config.js';
import { authenticateGoogleIdToken } from './auth.js';
import type { AuthenticatedUser } from './auth.js';
import { checkDatabase, closeDatabase, pool } from './db.js';
import { OpenAIProvider } from './openai-provider.js';
import type { ChatTurn } from './provider.js';

const app = Fastify({
  logger: {
    level: config.NODE_ENV === 'production' ? 'info' : 'debug',
    redact: {
      paths: ['req.headers.authorization', 'req.headers.cookie', '*.OPENAI_API_KEY', '*.apiKey'],
      censor: '[REDACTED]',
    },
  },
  bodyLimit: 32 * 1024,
  requestTimeout: config.OPENAI_TIMEOUT_MS + 10000,
});

const provider = new OpenAIProvider();
const requestSchema = z.object({
  message: z.string().trim().min(1).max(config.MAX_USER_MESSAGE_CHARS),
  conversationId: z.string().uuid().optional(),
});

declare module 'fastify' {
  interface FastifyRequest {
    authenticatedUser: AuthenticatedUser | null;
  }
}

app.decorateRequest('authenticatedUser', null);

await app.register(cors, {
  origin: config.allowedOrigins.length ? config.allowedOrigins : false,
  credentials: false,
});
await app.register(rateLimit, {
  global: false,
  keyGenerator: request => request.authenticatedUser?.id ?? request.ip,
});

app.get('/health', async () => ({ status: 'ok' }));

app.addHook('preHandler', async (request, reply) => {
  if (request.url === '/health') return;
  try {
    request.authenticatedUser = await authenticateGoogleIdToken(request);
  } catch (error) {
    const statusCode = (error as { statusCode?: number }).statusCode ?? 401;
    return reply.code(statusCode).send({ error: 'unauthorized', message: 'Authentication required.' });
  }
});

app.get('/v1/conversations', {
  config: { rateLimit: { max: config.RATE_LIMIT_MAX, timeWindow: config.RATE_LIMIT_WINDOW } },
}, async request => {
  const user = request.authenticatedUser!;
  const result = await pool.query(
    'SELECT id, title, created_at, updated_at FROM ai_conversations WHERE user_id = $1 ORDER BY updated_at DESC LIMIT 100',
    [user.id],
  );
  return { conversations: result.rows };
});

app.get<{ Params: { id: string } }>('/v1/conversations/:id/messages', async (request, reply) => {
  const user = request.authenticatedUser!;
  const id = z.string().uuid().safeParse(request.params.id);
  if (!id.success) return reply.code(400).send({ error: 'invalid_conversation_id' });
  const owned = await pool.query(
    'SELECT id FROM ai_conversations WHERE id = $1 AND user_id = $2',
    [id.data, user.id],
  );
  if (!owned.rowCount) return reply.code(404).send({ error: 'conversation_not_found' });
  const result = await pool.query(
    'SELECT id, role, content, model, input_tokens, output_tokens, created_at FROM ai_messages WHERE conversation_id = $1 AND user_id = $2 ORDER BY id ASC',
    [id.data, user.id],
  );
  return { messages: result.rows };
});

async function prepareConversation(user: AuthenticatedUser, message: string, requestedId?: string) {
  const id = requestedId ?? randomUUID();
  if (requestedId) {
    const owned = await pool.query(
      'SELECT id FROM ai_conversations WHERE id = $1 AND user_id = $2',
      [id, user.id],
    );
    if (!owned.rowCount) {
      const error = new Error('Conversation not found.') as Error & { statusCode: number };
      error.statusCode = 404;
      throw error;
    }
  } else {
    await pool.query(
      'INSERT INTO ai_conversations (id, user_id, title) VALUES ($1, $2, $3)',
      [id, user.id, message.slice(0, 72)],
    );
  }

  await pool.query(
    'INSERT INTO ai_messages (conversation_id, user_id, role, content) VALUES ($1, $2, $3, $4)',
    [id, user.id, 'user', message],
  );
  await pool.query(
    'UPDATE ai_conversations SET updated_at = NOW() WHERE id = $1 AND user_id = $2',
    [id, user.id],
  );

  const history = await pool.query(
    `SELECT role, content FROM (
       SELECT id, role, content FROM ai_messages
       WHERE conversation_id = $1 AND user_id = $2
       ORDER BY id DESC LIMIT $3
     ) recent ORDER BY id ASC`,
    [id, user.id, config.MAX_CONTEXT_MESSAGES],
  );
  return { id, history: history.rows as ChatTurn[] };
}

app.post('/v1/chat', {
  config: { rateLimit: { max: config.RATE_LIMIT_MAX, timeWindow: config.RATE_LIMIT_WINDOW } },
}, async (request, reply) => {
  const parsed = requestSchema.safeParse(request.body);
  if (!parsed.success) return reply.code(400).send({ error: 'invalid_request', details: parsed.error.issues });
  const user = request.authenticatedUser!;
  const { id, history } = await prepareConversation(user, parsed.data.message, parsed.data.conversationId);
  const controller = new AbortController();
  request.raw.once('aborted', () => controller.abort());
  const generated = await provider.generate({
    systemPrompt: await loadSystemPrompt(),
    history,
    signal: controller.signal,
  });
  await pool.query(
    `INSERT INTO ai_messages
      (conversation_id, user_id, role, content, model, input_tokens, output_tokens)
     VALUES ($1, $2, 'assistant', $3, $4, $5, $6)`,
    [id, user.id, generated.text, generated.model, generated.inputTokens, generated.outputTokens],
  );
  await pool.query(
    'UPDATE ai_conversations SET updated_at = NOW() WHERE id = $1 AND user_id = $2',
    [id, user.id],
  );
  return {
    conversationId: id,
    message: generated.text,
    usage: { inputTokens: generated.inputTokens, outputTokens: generated.outputTokens },
    model: generated.model,
  };
});

app.post('/v1/chat/stream', {
  config: { rateLimit: { max: config.RATE_LIMIT_MAX, timeWindow: config.RATE_LIMIT_WINDOW } },
}, async (request, reply) => {
  const parsed = requestSchema.safeParse(request.body);
  if (!parsed.success) return reply.code(400).send({ error: 'invalid_request', details: parsed.error.issues });
  const user = request.authenticatedUser!;
  const { id, history } = await prepareConversation(user, parsed.data.message, parsed.data.conversationId);
  const controller = new AbortController();
  request.raw.once('aborted', () => controller.abort());

  reply.hijack();
  reply.raw.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  const send = (event: string, data: unknown) => {
    if (!reply.raw.destroyed) reply.raw.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
  };

  let answer = '';
  try {
    send('meta', { conversationId: id, model: config.OPENAI_MODEL });
    for await (const delta of provider.stream({
      systemPrompt: await loadSystemPrompt(),
      history,
      signal: controller.signal,
    })) {
      answer += delta;
      send('delta', { text: delta });
    }
    if (!answer.trim()) throw new Error('The AI provider returned an empty response.');
    await pool.query(
      `INSERT INTO ai_messages (conversation_id, user_id, role, content, model)
       VALUES ($1, $2, 'assistant', $3, $4)`,
      [id, user.id, answer, config.OPENAI_MODEL],
    );
    await pool.query(
      'UPDATE ai_conversations SET updated_at = NOW() WHERE id = $1 AND user_id = $2',
      [id, user.id],
    );
    send('done', { conversationId: id });
  } catch (error) {
    request.log.error({ err: error }, 'AI stream failed');
    send('error', { message: 'The AI response could not be completed. Please retry.' });
  } finally {
    if (!reply.raw.destroyed) reply.raw.end();
  }
});

app.setErrorHandler((error, request, reply) => {
  request.log.error({ err: error }, 'Request failed');
  const statusCode = (error as { statusCode?: number }).statusCode;
  if (reply.sent) return;
  if (statusCode === 404) return reply.code(404).send({ error: 'not_found' });
  return reply.code(statusCode && statusCode >= 400 && statusCode < 500 ? statusCode : 502)
    .send({ error: 'request_failed', message: 'The request could not be completed.' });
});

try {
  await checkDatabase();
  await app.listen({ host: config.HOST, port: config.PORT });
} catch (error) {
  app.log.error({ err: error }, 'AI gateway startup failed');
  await closeDatabase();
  process.exit(1);
}

const shutdown = async () => {
  await app.close();
  await closeDatabase();
  process.exit(0);
};
process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
