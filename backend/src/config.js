import path from 'node:path'
import { fileURLToPath } from 'node:url'
import dotenv from 'dotenv'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

dotenv.config({
  path: path.resolve(__dirname, '../.env'),
  override: true,
})

function required(name) {
  const value = process.env[name]
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`)
  }
  return value
}

function requiredOneOf(...names) {
  for (const name of names) {
    const value = process.env[name]
    if (value) {
      return value
    }
  }

  throw new Error(`Missing required environment variable. Expected one of: ${names.join(', ')}`)
}

export const config = {
  port: Number(process.env.PORT || 8787),
  supabaseUrl: required('SUPABASE_URL'),
  supabasePublishableKey: requiredOneOf('SUPABASE_PUBLISHABLE_KEY', 'SUPABASE_ANON_KEY'),
  supabaseServiceRoleKey: required('SUPABASE_SERVICE_ROLE_KEY'),
  openAIApiKey: required('OPENAI_API_KEY'),
  transcriptionModel: process.env.OPENAI_TRANSCRIPTION_MODEL || 'gpt-4o-mini-transcribe',
  summaryModel: process.env.OPENAI_SUMMARY_MODEL || 'gpt-4.1-mini',
  storageBucket: process.env.SUPABASE_STORAGE_BUCKET || 'meeting-audio',
}
