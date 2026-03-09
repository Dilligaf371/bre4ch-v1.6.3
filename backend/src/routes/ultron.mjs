import { Router } from 'express';
import { OLLAMA_URL, ULTRON_MODEL, ULTRON_SOUL, MAX_HISTORY } from '../config.mjs';
import { getCurrentDateContext, ROAR_CONTEXT } from '../context.mjs';
import { createSessionStore } from '../sessions.mjs';

const router = Router();
const sessions = createSessionStore('ULTRON');

router.post('/ultron', async (req, res) => {
  const { message, sessionId = 'default' } = req.body;
  if (!message) return res.status(400).json({ error: 'Message required' });

  const session = sessions.get(sessionId);
  const history = session.messages;

  history.push({ role: 'user', content: message });
  while (history.length > MAX_HISTORY) history.shift();

  const systemPrompt = [getCurrentDateContext(), ULTRON_SOUL, ROAR_CONTEXT].filter(Boolean).join('\n\n');

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 180_000);

  try {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const response = await fetch(`${OLLAMA_URL}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: ULTRON_MODEL,
        messages: [{ role: 'system', content: systemPrompt }, ...history],
        stream: true,
        options: { num_ctx: 8192, temperature: 0.7, top_p: 0.9 },
      }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!response.ok) {
      const errText = await response.text();
      console.error(`[ULTRON] Ollama error: ${response.status} ${errText}`);
      res.write(`data: ${JSON.stringify({ error: `Ollama error: ${response.status}` })}\n\n`);
      res.write('data: [DONE]\n\n');
      res.end();
      history.pop();
      return;
    }

    let fullResponse = '';
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const parsed = JSON.parse(line);
          if (parsed.message?.content) {
            fullResponse += parsed.message.content;
            res.write(`data: ${JSON.stringify({ text: parsed.message.content })}\n\n`);
          }
          if (parsed.done) break;
        } catch { /* skip unparseable */ }
      }
    }

    if (fullResponse) {
      history.push({ role: 'assistant', content: fullResponse });
      while (history.length > MAX_HISTORY + 10) history.shift();
    }

    res.write('data: [DONE]\n\n');
    res.end();
  } catch (error) {
    clearTimeout(timeout);
    const errorMsg = error.name === 'AbortError' ? 'Request timed out (180s)' : error.message;
    console.error(`[ULTRON] Error: ${errorMsg}`);
    try {
      res.write(`data: ${JSON.stringify({ error: errorMsg })}\n\n`);
      res.write('data: [DONE]\n\n');
      res.end();
    } catch { /* response already ended */ }
    if (history.length > 0 && history.at(-1).role === 'user') history.pop();
  }
});

export { sessions as ultronSessions };
export default router;
