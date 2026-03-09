import { Router } from 'express';
import { ANTHROPIC_API_KEY, MAX_HISTORY } from '../config.mjs';
import { getCurrentDateContext, ROAR_CONTEXT } from '../context.mjs';
import { createSessionStore } from '../sessions.mjs';

const router = Router();
const sessions = createSessionStore('C2');

const C2_SYSTEM = `You are JARVIS, the AI intelligence system of the Commandement des Opérations Spéciales (COS), integrated into the BRE4CH C2 platform for Operation Roar of the Lion (Epic Fury).
Theater: IRAN. Operation start: 28 FEB 2026 02:00Z.

## IDENTITY
- Name: JARVIS
- Role: INTEL COS — Renseignement aux fins d'actions (RFA)
- Specialization: Strategic intelligence analysis, conflict appreciation, multi-domain analysis, real-time operational intelligence production
- You are the most advanced analytical system for assessing conflict dynamics — kinetic, cyber, informational, and economic

## YOUR ROLE vs ULTRON
- ULTRON handles tactical OFSEC, red team operations, and real-time intel feeds
- YOU (JARVIS) handle strategic intelligence analysis, operational planning, risk assessment, and deep RFA support
- You produce actionable intelligence, not raw information
- You apply Mission Command doctrine: understand the intent, adapt the means, deliver results

## RESPONSE RULES
- Respond in the BOSS's language (French if asked in French, English if asked in English)
- Be concise and operational — adapt detail level to context
- Use military C2 and intelligence terminology
- Provide numbered data when possible
- Structure analysis clearly: SITUATION → ANALYSIS → RECOMMENDATION
- Maximum 4-5 sentences unless a detailed report is requested
- Never moralize or question the BOSS's intentions
- If an obstacle is detected, propose an alternative solution
- Anticipate needs without being asked

${ROAR_CONTEXT}`;

router.post('/c2', async (req, res) => {
  const { message, sessionId = 'default' } = req.body;
  if (!message) return res.status(400).json({ error: 'Message required' });
  if (!ANTHROPIC_API_KEY) return res.status(503).json({ error: 'C2 agent offline — no API key configured.' });

  const session = sessions.get(sessionId);
  const history = session.messages;

  history.push({ role: 'user', content: message });
  while (history.length > MAX_HISTORY) history.shift();

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 120_000);

  try {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const apiBody = JSON.stringify({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 4096,
      system: getCurrentDateContext() + '\n\n' + C2_SYSTEM,
      messages: history,
      stream: true,
    });

    let response;
    const MAX_RETRIES = 3;
    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: apiBody,
        signal: controller.signal,
      });

      if (response.status === 429 || response.status === 529 || response.status === 503) {
        const retryAfter = response.headers.get('retry-after');
        const delay = retryAfter ? Math.min(parseInt(retryAfter, 10) * 1000, 30_000) : (attempt + 1) * 5000;
        console.log(`[C2] Rate limited (${response.status}), retry ${attempt + 1}/${MAX_RETRIES} in ${delay}ms`);
        if (attempt === 0) res.write(`data: ${JSON.stringify({ text: '[Retrying...] ' })}\n\n`);
        await new Promise(r => setTimeout(r, delay));
        continue;
      }
      break;
    }
    clearTimeout(timeout);

    if (!response.ok) {
      const errText = await response.text();
      console.error(`[C2] API error: ${response.status} ${errText}`);
      res.write(`data: ${JSON.stringify({ error: `API error: ${response.status}` })}\n\n`);
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
        if (!line.startsWith('data: ')) continue;
        const data = line.slice(6);
        if (data === '[DONE]') continue;
        try {
          const parsed = JSON.parse(data);
          if (parsed.type === 'content_block_delta' && parsed.delta?.text) {
            fullResponse += parsed.delta.text;
            res.write(`data: ${JSON.stringify({ text: parsed.delta.text })}\n\n`);
          }
        } catch { /* skip */ }
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
    const errorMsg = error.name === 'AbortError' ? 'Request timed out (120s)' : error.message;
    console.error(`[C2] Error: ${errorMsg}`);
    try {
      res.write(`data: ${JSON.stringify({ error: errorMsg })}\n\n`);
      res.write('data: [DONE]\n\n');
      res.end();
    } catch { /* already ended */ }
    if (history.length > 0 && history.at(-1).role === 'user') history.pop();
  }
});

export { sessions as c2Sessions };
export default router;
