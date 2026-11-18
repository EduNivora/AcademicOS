import test from 'node:test';
import assert from 'node:assert/strict';
import { selectRecentContext } from './context.js';

test('keeps only the newest configured number of turns', () => {
  const turns = [
    { role: 'user' as const, content: 'one' },
    { role: 'assistant' as const, content: 'two' },
    { role: 'user' as const, content: 'three' },
  ];
  assert.deepEqual(selectRecentContext(turns, 2), turns.slice(1));
});

test('removes empty turns and bounds individual message size', () => {
  const turns = [
    { role: 'user' as const, content: '   ' },
    { role: 'assistant' as const, content: 'abcdef' },
  ];
  assert.deepEqual(selectRecentContext(turns, 10, 3), [
    { role: 'assistant', content: 'def' },
  ]);
});