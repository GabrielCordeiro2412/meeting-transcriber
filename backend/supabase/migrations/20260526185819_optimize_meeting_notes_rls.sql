create index if not exists meetings_user_id_idx
on public.meetings (user_id);

create index if not exists meeting_jobs_meeting_id_idx
on public.meeting_jobs (meeting_id);

drop policy if exists "users can read own meetings" on public.meetings;
drop policy if exists "users can insert own meetings" on public.meetings;
drop policy if exists "users can update own meetings" on public.meetings;
drop policy if exists "users can read own meeting jobs" on public.meeting_jobs;

create policy "users can read own meetings"
on public.meetings
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users can insert own meetings"
on public.meetings
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "users can update own meetings"
on public.meetings
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "users can read own meeting jobs"
on public.meeting_jobs
for select
to authenticated
using (
  exists (
    select 1
    from public.meetings
    where public.meetings.id = public.meeting_jobs.meeting_id
      and public.meetings.user_id = (select auth.uid())
  )
);
