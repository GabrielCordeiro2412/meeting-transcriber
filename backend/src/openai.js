import { config } from './config.js'

const transcriptionPrompt = 'Transcribe in Brazilian Portuguese with clear punctuation. Preserve proper names, technical terms, decisions, next steps, and questions discussed in the meeting.'

export async function transcribeAudio({ data, filename, mimeType }) {
  const formData = new FormData()
  formData.append('model', config.transcriptionModel)
  formData.append('response_format', 'json')
  formData.append('language', 'pt')
  formData.append('prompt', transcriptionPrompt)
  formData.append('file', new Blob([data], { type: mimeType }), filename)

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.openAIApiKey}`,
    },
    body: formData,
  })

  if (!response.ok) {
    throw await openAIError(response)
  }

  const payload = await response.json()
  return String(payload.text || '').trim()
}

export async function summarizeTranscript(transcript) {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.openAIApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: config.summaryModel,
      messages: [
        {
          role: 'system',
          content: 'You convert meeting transcripts into complete, practical meeting notes. Write in the same language as the transcript. Be specific and preserve concrete details, decisions, tradeoffs, examples, numbers, blockers, and follow-up context. Return JSON that follows the provided schema exactly.',
        },
        {
          role: 'user',
          content: transcript,
        },
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'meeting_summary',
          strict: true,
          schema: {
            type: 'object',
            additionalProperties: false,
            properties: {
              title: { type: 'string' },
              summary: { type: 'string' },
              detailedNotes: { type: 'array', items: { type: 'string' } },
              topics: { type: 'array', items: { type: 'string' } },
              keyPoints: { type: 'array', items: { type: 'string' } },
              decisions: { type: 'array', items: { type: 'string' } },
              actionItems: { type: 'array', items: { type: 'string' } },
              openQuestions: { type: 'array', items: { type: 'string' } },
              risksOrBlockers: { type: 'array', items: { type: 'string' } },
              followUpItems: { type: 'array', items: { type: 'string' } },
            },
            required: [
              'title',
              'summary',
              'detailedNotes',
              'topics',
              'keyPoints',
              'decisions',
              'actionItems',
              'openQuestions',
              'risksOrBlockers',
              'followUpItems',
            ],
          },
        },
      },
    }),
  })

  if (!response.ok) {
    throw await openAIError(response)
  }

  const payload = await response.json()
  const content = payload.choices?.[0]?.message?.content
  if (!content) {
    throw new Error('OpenAI summary response was empty.')
  }

  return JSON.parse(content)
}

async function openAIError(response) {
  try {
    const payload = await response.json()
    const code = payload.error?.code ? ` (${payload.error.code})` : ''
    const requestID = response.headers.get('x-request-id')
    const requestSuffix = requestID ? ` [request_id=${requestID}]` : ''
    return new Error(`${response.status}${code}: ${payload.error?.message || 'OpenAI request failed.'}${requestSuffix}`)
  } catch {
    const requestID = response.headers.get('x-request-id')
    const requestSuffix = requestID ? ` [request_id=${requestID}]` : ''
    return new Error(`OpenAI request failed with status ${response.status}.${requestSuffix}`)
  }
}
