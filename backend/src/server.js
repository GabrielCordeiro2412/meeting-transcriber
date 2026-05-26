import express from 'express'
import multer from 'multer'
import { config } from './config.js'
import { summarizeTranscript, transcribeAudio } from './openai.js'
import { requireUser, supabaseAdmin, supabaseAuth } from './supabase.js'

const app = express()
const upload = multer({ storage: multer.memoryStorage() })

app.use(express.json({ limit: '4mb' }))

app.get('/health', (_req, res) => {
  res.json({ ok: true })
})

app.post('/auth/magic-link', async (req, res) => {
  const email = String(req.body?.email || '').trim()
  const redirectUrl = String(req.body?.redirectUrl || '').trim()

  if (!email || !redirectUrl) {
    res.status(400).json({ error: 'email and redirectUrl are required.' })
    return
  }

  const { error } = await supabaseAuth.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: redirectUrl,
    },
  })

  if (error) {
    res.status(400).json({ error: error.message })
    return
  }

  res.status(202).json({ ok: true })
})

app.get('/auth/me', requireUser, async (req, res) => {
  res.json({
    userId: req.user.id,
    email: req.user.email || '',
  })
})

app.get('/meetings', requireUser, async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('meetings')
    .select('*')
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false })

  if (error) {
    res.status(500).json({ error: error.message })
    return
  }

  res.json((data || []).map(toMeetingResponse))
})

app.get('/meetings/:id', requireUser, async (req, res) => {
  const meeting = await fetchMeeting(req.params.id, req.user.id)
  if (!meeting) {
    res.status(404).json({ error: 'Meeting not found.' })
    return
  }
  res.json(toMeetingResponse(meeting))
})

app.post('/meetings', requireUser, async (req, res) => {
  const payload = {
    id: req.body?.id,
    user_id: req.user.id,
    title: String(req.body?.title || 'Meeting'),
    started_at: req.body?.startedAt || null,
    ended_at: req.body?.endedAt || null,
    capture_mode: req.body?.captureMode || 'microphoneOnly',
    status: 'draft',
  }

  const { data, error } = await supabaseAdmin
    .from('meetings')
    .upsert(payload)
    .select('*')
    .single()

  if (error) {
    res.status(500).json({ error: error.message })
    return
  }

  res.status(201).json(toMeetingResponse(data))
})

app.post('/meetings/:id/upload', requireUser, upload.array('files'), async (req, res) => {
  const source = req.query.source === 'system' ? 'system' : 'microphone'
  const meeting = await fetchMeeting(req.params.id, req.user.id)
  if (!meeting) {
    res.status(404).json({ error: 'Meeting not found.' })
    return
  }

  const files = Array.isArray(req.files) ? req.files : []
  if (files.length === 0) {
    res.status(400).json({ error: 'No audio files were uploaded.' })
    return
  }

  const uploadedPaths = []
  for (const file of files) {
    const storagePath = `${req.user.id}/${meeting.id}/${source}/${Date.now()}-${file.originalname}`
    const { error } = await supabaseAdmin
      .storage
      .from(config.storageBucket)
      .upload(storagePath, file.buffer, {
        contentType: file.mimetype || 'application/octet-stream',
        upsert: true,
      })

    if (error) {
      res.status(500).json({ error: error.message })
      return
    }
    uploadedPaths.push(storagePath)
  }

  const update = source === 'microphone'
    ? { microphone_storage_paths: [...(meeting.microphone_storage_paths || []), ...uploadedPaths], status: 'uploaded' }
    : { system_storage_paths: [...(meeting.system_storage_paths || []), ...uploadedPaths], status: 'uploaded' }

  const { error } = await supabaseAdmin
    .from('meetings')
    .update(update)
    .eq('id', meeting.id)
    .eq('user_id', req.user.id)

  if (error) {
    res.status(500).json({ error: error.message })
    return
  }

  res.status(202).json({ ok: true, uploadedPaths })
})

app.post('/meetings/:id/process', requireUser, async (req, res) => {
  const meeting = await fetchMeeting(req.params.id, req.user.id)
  if (!meeting) {
    res.status(404).json({ error: 'Meeting not found.' })
    return
  }

  const jobStart = await supabaseAdmin
    .from('meeting_jobs')
    .insert({ meeting_id: meeting.id, status: 'started' })
    .select('*')
    .single()

  try {
    await updateMeetingStatus(meeting.id, req.user.id, 'transcribing', null)

    const transcriptParts = []

    for (const sourcePath of meeting.microphone_storage_paths || []) {
      const source = await downloadStorageObject(sourcePath)
      const transcript = await transcribeAudio(source)
      if (transcript) {
        transcriptParts.push(transcript)
      }
    }

    for (const sourcePath of meeting.system_storage_paths || []) {
      const source = await downloadStorageObject(sourcePath)
      const transcript = await transcribeAudio(source)
      if (transcript) {
        transcriptParts.push(transcript)
      }
    }

    const transcript = transcriptParts.join('\n\n').trim()
    if (!transcript) {
      throw new Error('The transcript is empty.')
    }

    await supabaseAdmin
      .from('meetings')
      .update({
        transcript_text: transcript,
        status: 'summarizing',
      })
      .eq('id', meeting.id)
      .eq('user_id', req.user.id)

    const summaryPayload = await summarizeTranscript(transcript)

    const summaryText = String(summaryPayload.summary || '').trim()
    const title = String(summaryPayload.title || meeting.title || 'Meeting').trim() || 'Meeting'

    const { data, error } = await supabaseAdmin
      .from('meetings')
      .update({
        title,
        transcript_text: transcript,
        summary_text: summaryText,
        summary_payload: summaryPayload,
        processing_error: null,
        status: 'completed',
      })
      .eq('id', meeting.id)
      .eq('user_id', req.user.id)
      .select('*')
      .single()

    if (error) {
      throw error
    }

    if (jobStart.data?.id) {
      await supabaseAdmin
        .from('meeting_jobs')
        .update({ status: 'completed' })
        .eq('id', jobStart.data.id)
    }

    res.json(toMeetingResponse(data))
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Meeting processing failed.'
    await updateMeetingStatus(meeting.id, req.user.id, 'failed', message)

    if (jobStart.data?.id) {
      await supabaseAdmin
        .from('meeting_jobs')
        .update({ status: 'failed', error_message: message })
        .eq('id', jobStart.data.id)
    }

    res.status(500).json({ error: message })
  }
})

app.patch('/meetings/:id', requireUser, async (req, res) => {
  const summaryPayload = req.body?.summaryPayload || {}
  const patch = {
    title: String(req.body?.title || 'Meeting').trim() || 'Meeting',
    summary_text: String(req.body?.summaryText || ''),
    transcript_text: String(req.body?.transcriptText || ''),
    summary_payload: summaryPayload,
  }

  const { data, error } = await supabaseAdmin
    .from('meetings')
    .update(patch)
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .select('*')
    .single()

  if (error) {
    res.status(500).json({ error: error.message })
    return
  }

  res.json(toMeetingResponse(data))
})

app.use((error, _req, res, _next) => {
  const message = error instanceof Error ? error.message : 'Unexpected server error.'
  res.status(500).json({ error: message })
})

app.listen(config.port, () => {
  console.log(`Meeting Notes backend listening on http://127.0.0.1:${config.port}`)
})

async function fetchMeeting(id, userId) {
  const { data } = await supabaseAdmin
    .from('meetings')
    .select('*')
    .eq('id', id)
    .eq('user_id', userId)
    .maybeSingle()

  return data
}

async function updateMeetingStatus(id, userId, status, processingError) {
  await supabaseAdmin
    .from('meetings')
    .update({
      status,
      processing_error: processingError,
    })
    .eq('id', id)
    .eq('user_id', userId)
}

async function downloadStorageObject(path) {
  const { data, error } = await supabaseAdmin
    .storage
    .from(config.storageBucket)
    .download(path)

  if (error) {
    throw error
  }

  const arrayBuffer = await data.arrayBuffer()
  return {
    data: Buffer.from(arrayBuffer),
    filename: path.split('/').pop() || 'meeting-audio.m4a',
    mimeType: data.type || 'application/octet-stream',
  }
}

function toMeetingResponse(row) {
  return {
    id: row.id,
    userId: row.user_id,
    createdAt: row.created_at,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    title: row.title,
    status: row.status,
    captureMode: row.capture_mode,
    transcriptText: row.transcript_text || '',
    summaryText: row.summary_text || '',
    summaryPayload: normalizeSummaryPayload(row.summary_payload, row.title, row.summary_text),
    processingError: row.processing_error,
  }
}

function normalizeSummaryPayload(payload, fallbackTitle, fallbackSummary) {
  const safe = payload && typeof payload === 'object' ? payload : {}
  return {
    title: String(safe.title || fallbackTitle || 'Meeting'),
    summary: String(safe.summary || fallbackSummary || ''),
    detailedNotes: Array.isArray(safe.detailedNotes) ? safe.detailedNotes : [],
    topics: Array.isArray(safe.topics) ? safe.topics : [],
    keyPoints: Array.isArray(safe.keyPoints) ? safe.keyPoints : [],
    decisions: Array.isArray(safe.decisions) ? safe.decisions : [],
    actionItems: Array.isArray(safe.actionItems) ? safe.actionItems : [],
    openQuestions: Array.isArray(safe.openQuestions) ? safe.openQuestions : [],
    risksOrBlockers: Array.isArray(safe.risksOrBlockers) ? safe.risksOrBlockers : [],
    followUpItems: Array.isArray(safe.followUpItems) ? safe.followUpItems : [],
  }
}
