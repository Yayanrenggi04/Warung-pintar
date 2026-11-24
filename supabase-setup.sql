-- =====================================================================
-- Warung Pintar 2.0 - penyimpanan data di server (Supabase)
--
-- Cara memakai:
--   1. Buka proyek Supabase Anda, lalu menu "SQL Editor".
--   2. Tempel seluruh isi berkas ini, lalu tekan "Run".
--   3. Selesai. Skrip ini aman dijalankan berulang kali.
--
-- Isi: satu tabel (wp_rows) untuk produk, penjualan, biaya, dan profil toko,
-- dengan Row Level Security. Setiap pemilik akun hanya bisa membaca dan
-- mengubah barisnya sendiri. Kunci "anon" tanpa login tidak bisa mengakses apa pun.
-- =====================================================================

create table if not exists public.wp_rows (
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  kind       text        not null check (kind in ('product', 'sale', 'expense', 'profile')),
  id         text        not null check (char_length(id) between 1 and 80),
  data       jsonb       not null default '{}'::jsonb check (octet_length(data::text) <= 100000),
  ts         bigint      not null default 0,        -- waktu terakhir diubah di perangkat (milidetik)
  deleted    boolean     not null default false,    -- true = sudah dihapus, disimpan agar perangkat lain ikut menghapus
  updated_at timestamptz not null default now(),    -- diisi server, dipakai untuk menarik perubahan baru
  primary key (user_id, kind, id)
);

create index if not exists wp_rows_user_updated_idx on public.wp_rows (user_id, updated_at);

-- Setiap baris yang ditulis: (1) waktu server dicatat otomatis, (2) waktu ubah dari
-- perangkat tidak boleh lebih dari semenit di depan jam server, (3) tulisan yang lebih
-- lama dari isi di server diabaikan, sehingga perangkat yang baru online tidak menimpa
-- perubahan yang lebih baru dari perangkat lain.
create or replace function public.wp_rows_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.ts := least(new.ts, (extract(epoch from now()) * 1000)::bigint + 60000);
  if tg_op = 'UPDATE' and new.ts < old.ts then
    return null;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists wp_rows_touch on public.wp_rows;
create trigger wp_rows_touch
  before insert or update on public.wp_rows
  for each row execute function public.wp_rows_touch();

-- Keamanan: hanya pemilik baris yang boleh membaca dan menulis.
alter table public.wp_rows enable row level security;

drop policy if exists "wp_rows_select_own" on public.wp_rows;
create policy "wp_rows_select_own" on public.wp_rows
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "wp_rows_insert_own" on public.wp_rows;
create policy "wp_rows_insert_own" on public.wp_rows
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "wp_rows_update_own" on public.wp_rows;
create policy "wp_rows_update_own" on public.wp_rows
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "wp_rows_delete_own" on public.wp_rows;
create policy "wp_rows_delete_own" on public.wp_rows
  for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.wp_rows from anon;
revoke all on public.wp_rows from public;
revoke all on public.wp_rows from authenticated;   -- buang hak bawaan Supabase (mis. truncate), lalu beri yang perlu saja
grant select, insert, update, delete on public.wp_rows to authenticated;

-- ---------------------------------------------------------------------
-- Opsional: tampilan yang mudah dibaca di Table Editor Supabase.
-- Hanya menampilkan data akun yang sedang login (di Table Editor, jalankan
-- sebagai pemilik proyek, jadi lihat tabel wp_rows langsung untuk semua data).
-- ---------------------------------------------------------------------
do $$
begin
  if current_setting('server_version_num')::int >= 150000 then
    execute $v$
      create or replace view public.wp_produk with (security_invoker = true) as
      select id,
             data->>'n'              as nama,
             data->>'b'              as barcode,
             (data->>'c')::numeric   as hpp,
             (data->>'p')::numeric   as harga_jual,
             (data->>'s')::numeric   as stok,
             (data->>'m')::numeric   as stok_minimum,
             to_timestamp(ts / 1000.0) as diubah
      from public.wp_rows
      where kind = 'product' and not deleted
    $v$;
    execute $v$
      create or replace view public.wp_penjualan with (security_invoker = true) as
      select id,
             to_timestamp((data->>'t')::numeric / 1000.0) as waktu,
             (data->>'total')::numeric as total,
             (data->>'disc')::numeric  as diskon,
             jsonb_array_length(data->'items') as jumlah_jenis_barang,
             data->'items'             as barang
      from public.wp_rows
      where kind = 'sale' and not deleted
    $v$;
    execute $v$
      create or replace view public.wp_biaya with (security_invoker = true) as
      select id,
             to_timestamp((data->>'t')::numeric / 1000.0) as waktu,
             data->>'c'              as kategori,
             data->>'n'              as catatan,
             (data->>'a')::numeric   as jumlah
      from public.wp_rows
      where kind = 'expense' and not deleted
    $v$;
    execute 'revoke all on public.wp_produk, public.wp_penjualan, public.wp_biaya from anon, authenticated';
    execute 'grant select on public.wp_produk, public.wp_penjualan, public.wp_biaya to authenticated';
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- Hapus akun sendiri (tombol "Hapus akun" di Pengaturan).
-- Menghapus akun pemilik dan, lewat ON DELETE CASCADE, semua barisnya di wp_rows.
-- ---------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

