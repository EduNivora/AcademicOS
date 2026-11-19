import OpenAI from 'openai';
import { config } from './config.js';
import type { AIProvider, ChatTurn, GenerationRequest, GenerationResult, ProviderStreamEvent } from './provider.js';

export class OpenAIProvider implements AIProvider {
  readonly name = 'openai';
  private readonly client = new OpenAI({
    apiKey: config.OPENAI_API_KEY,
    timeout: config.OPENAI_TIMEOUT_MS,
    maxRetries: 2,
  });

  private messages(systemPrompt: string, history: ChatTurn[]) {
    return [
      { role: 'system' as const, content: systemPrompt },
      ...history.map(turn => ({ role: turn.role, content: turn.content })),
    ];
  }

  async generate(request: GenerationRequest): Promise<GenerationResult> {
    const response = await this.client.chat.completions.create({
      model: config.OPENAI_MODEL,
      messages: this.messages(request.systemPrompt, request.history),
      max_tokens: config.OPENAI_MAX_OUTPUT_TOKENS,
    }, { signal: request.signal });

    const text = response.choices[0]?.message?.content?.trim() ?? '';
    if (!text) throw new Error('The AI provider returned an empty response.');
    return {
      text,
      inputTokens: response.usage?.prompt_tokens ?? 0,
      outputTokens: response.usage?.completion_tokens ?? 0,
      model: response.model,
    };
  }

  async *stream(request: GenerationRequest): AsyncIterable<ProviderStreamEvent> {
    const stream = await this.client.chat.completions.create({
      model: config.OPENAI_MODEL,
      messages: this.messages(request.systemPrompt, request.history),
      max_tokens: config.OPENAI_MAX_OUTPUT_TOKENS,
      stream: true,
      stream_options: { include_usage: true },
    }, { signal: request.signal });

    for await (const part of stream) {
      if (part.usage) {
        yield {
          type: 'usage',
          inputTokens: part.usage.prompt_tokens,
          outputTokens: part.usage.completion_tokens,
          model: part.model,
        };
      }
      const delta = part.choices[0]?.delta?.content;
      if (typeof delta === 'string' && delta.length) {
        yield { type: 'delta', text: delta };
      }
    }
  }
}