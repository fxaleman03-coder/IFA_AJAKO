import http from 'node:http';

const apiKey = process.env.OPENAI_API_KEY;
const model = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
const fallbackModel = process.env.OPENAI_FALLBACK_MODEL || 'gpt-4.1';
const port = Number(process.env.PORT || 8787);

if (!apiKey) {
  console.error('Missing OPENAI_API_KEY.');
  process.exit(1);
}

const systemPrompt = [
  'You are a translation engine.',
  'Translate from Spanish to English.',
  'Preserve Yoruba words, names, and Odu names exactly as-is.',
  'Preserve formatting, line breaks, and numbered lists.',
  'Do not remove or alter tokens like [[ATENA]].',
  'Return only the translated text with no commentary.'
].join(' ');

const server = http.createServer(async (req, res) => {
  if (req.method !== 'POST' || req.url !== '/translate') {
    res.statusCode = 404;
    res.end('Not found');
    return;
  }

  let body = '';
  req.on('data', (chunk) => {
    body += chunk;
  });

  req.on('end', async () => {
    try {
      const payload = JSON.parse(body || '{}');
      const text = String(payload.text || '').trim();
      const source = String(payload.source || 'es');
      const target = String(payload.target || 'en');

      if (!text) {
        res.statusCode = 400;
        res.end(JSON.stringify({ error: 'text_required' }));
        return;
      }

      const makeRequest = async (selectedModel) => {
        return fetch('https://api.openai.com/v1/responses', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: selectedModel,
            temperature: 0.2,
            input: [
              { role: 'system', content: systemPrompt },
              {
                role: 'user',
                content: `Translate from ${source} to ${target}.\n\n${text}`,
              },
            ],
          }),
        });
      };

      let response = await makeRequest(model);

      if (!response.ok) {
        const errText = await response.text();
        res.statusCode = 500;
        res.end(JSON.stringify({ error: 'openai_error', detail: errText }));
        return;
      }

      let data = await response.json();
      let outputText =
        data.output_text ||
        data.output?.[0]?.content
          ?.map((part) => part?.text || '')
          .join('') ||
        '';

      if (outputText.trim() === text.trim() && fallbackModel) {
        response = await makeRequest(fallbackModel);
        if (response.ok) {
          data = await response.json();
          outputText =
            data.output_text ||
            data.output?.[0]?.content
              ?.map((part) => part?.text || '')
              .join('') ||
            outputText;
        }
      }

      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ translation: outputText }));
    } catch (error) {
      res.statusCode = 500;
      res.end(JSON.stringify({ error: 'server_error' }));
    }
  });
});

server.listen(port, () => {
  console.log(`Translation server listening on http://localhost:${port}`);
});
