import { createClient } from '@supabase/supabase-js'
import { config } from './config.js'

export const supabaseAdmin = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
})

export const supabaseAuth = createClient(config.supabaseUrl, config.supabasePublishableKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
})

export async function requireUser(req, res, next) {
  const authHeader = req.headers.authorization || ''
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null

  if (!token) {
    res.status(401).json({ error: 'Missing access token.' })
    return
  }

  const { data, error } = await supabaseAdmin.auth.getUser(token)
  if (error || !data.user) {
    res.status(401).json({ error: 'Invalid or expired session.' })
    return
  }

  req.user = data.user
  req.accessToken = token
  next()
}
