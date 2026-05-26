create extension if not exists "pgcrypto";

create table if not exists public.meetings (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz,
  title text not null,
  status text not null default 'draft',
  capture_mode text not null default 'microphoneOnly',
  microphone_storage_paths text[] not null default '{}',
  system_storage_paths text[] not null default '{}',
  transcript_text text not null default '',
  summary_text text not null default '',
  summary_payload jsonb not null default '{}'::jsonb,
  processing_error text
);

create table if not exists public.meeting_jobs (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  created_at timestamptz not null default now(),
  status text not null,
  error_message text
);

alter table public.meetings enable row level security;
alter table public.meeting_jobs enable row level security;

create policy "users can read own meetings"
on public.meetings
for select
to authenticated
using (auth.uid() = user_id);

create policy "users can insert own meetings"
on public.meetings
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "users can update own meetings"
on public.meetings
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users can read own meeting jobs"
on public.meeting_jobs
for select
to authenticated
using (
  exists (
    select 1
    from public.meetings
    where public.meetings.id = public.meeting_jobs.meeting_id
      and public.meetings.user_id = auth.uid()
  )
);

insert into storage.buckets (id, name, public)
values ('meeting-audio', 'meeting-audio', false)
on conflict (id) do nothing;
