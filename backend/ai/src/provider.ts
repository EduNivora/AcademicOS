export type ChatRole = 'user' | 'assistant';
export type ChatTurn = { role: ChatRole; content: string };

export type GenerationRequest = {
  systemPrompt: string;
  history: ChatTurn[];
  signal: AbortSignal;
};

export type GenerationResult = {
  text: string;
  inputTokens: number;
  outputTokens: number;
  model: string;
};

export interface AIProvider {
  readonly name: string;
  generate(request: GenerationRequest): Promise<GenerationResult>;
  stream(request: GenerationRequest): AsyncIterable<string>;
}