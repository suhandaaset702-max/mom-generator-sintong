-- =====================================================================
-- Skema database MoM (Supabase). Jalankan SEKALI di: SQL Editor > New query > Run
-- Model akses: tim berbagi satu ruang kerja. Hanya email yang terdaftar di
-- tabel allowed_users yang dapat membaca/menulis meeting dan foto.
-- =====================================================================

-- 1. Daftar email yang diizinkan (tidak dapat dibaca langsung dari website)
create table if not exists public.allowed_users (
  email text primary key
);
alter table public.allowed_users enable row level security;   -- tanpa policy = tertutup untuk klien

-- 2. Fungsi pemeriksa akses
create or replace function public.is_member()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.allowed_users
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on function public.is_member() from public, anon;
grant execute on function public.is_member() to authenticated;

-- 3. Tabel meeting (isi dokumen disimpan di kolom JSON "data"; foto disimpan di Storage)
create table if not exists public.meetings (
  id           uuid primary key,
  created_by   uuid default auth.uid(),
  title        text,
  meeting_date date,
  discipline   text,
  status       text not null default 'draft' check (status in ('draft','saved')),
  data         jsonb not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists meetings_updated_idx on public.meetings (updated_at desc);
alter table public.meetings enable row level security;

drop policy if exists "member full access" on public.meetings;
create policy "member full access" on public.meetings
  for all to authenticated
  using (public.is_member())
  with check (public.is_member());

-- 4. Bucket foto (privat) + kebijakan akses
insert into storage.buckets (id, name, public)
values ('mom-images', 'mom-images', false)
on conflict (id) do nothing;

drop policy if exists "member access mom images" on storage.objects;
create policy "member access mom images" on storage.objects
  for all to authenticated
  using (bucket_id = 'mom-images' and public.is_member())
  with check (bucket_id = 'mom-images' and public.is_member());

-- 5. DAFTARKAN EMAIL ANDA (ganti, lalu jalankan). Tambah baris lagi untuk anggota tim lain.
-- insert into public.allowed_users (email) values ('GANTI-DENGAN-EMAIL-ANDA@contoh.com');
