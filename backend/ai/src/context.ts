import type { ChatTurn } from './provider.js';

export function selectRecentContext(
  history: ChatTurn[],
  maxMessages: number,
  maxCharsPerMessage = 12000,
): ChatTurn[] {
  return history
    .filter(turn =>
      (turn.role === 'user' || turn.role === 'assistant') &&
      typeof turn.content === 'string' &&
      turn.content.trim().length > 0,
    )
    .slice(-maxMessages)
    .map(turn => ({
      role: turn.role,
      content: turn.content.length > maxCharsPerMessage
        ? turn.content.slice(-maxCharsPerMessage)
        : turn.content,
    }));
}