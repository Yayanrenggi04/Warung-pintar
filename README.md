# Warung Pintar 2.1: paket pasang

Isi folder ini siap diunggah apa adanya ke hosting statis (Netlify, Hostinger, Cloudflare Pages, GitHub Pages).

| Berkas | Fungsi |
|---|---|
| `index.html` | Seluruh aplikasi (beranda, masuk, kasir, stok, riwayat, pengaturan) |
| `manifest.webmanifest`, `icons/` | Pasang di layar HP (ikon, nama, warna) |
| `sw.js` | Tetap bisa dibuka tanpa internet |
| `_headers` | Header keamanan dasar (Netlify dan Cloudflare Pages) |
| `supabase-setup.sql` | Skema server. Sudah dijalankan di proyek Anda; hanya perlu jika membuat proyek baru |

## Langkah di dashboard Supabase (tidak bisa dilakukan dari luar)

1. **Authentication > URL Configuration**: isi *Site URL* dengan alamat situs Anda (mis. `https://warungpintar.id`) dan tambahkan alamat yang sama di *Redirect URLs*. Tanpa ini, tautan konfirmasi email dan reset kata sandi mengarah ke alamat yang salah.
2. **Authentication > SMTP**: pasang SMTP sendiri (mis. Resend, Brevo). Email bawaan Supabase sangat dibatasi jumlahnya, jadi pendaftar baru bisa tidak menerima email.
3. **Authentication > Attack Protection**: aktifkan perlindungan kata sandi bocor jika paket Anda mendukung.
4. Proyek paket gratis dijeda setelah lama tidak aktif. Buka dashboard sesekali, atau upgrade bila pengguna sudah banyak.

## Domain sendiri

Unggah folder ini, lalu di pengaturan domain hosting arahkan domain Anda ke situs ini. Setelah domain aktif, perbarui *Site URL* di langkah 1.

## Email kontak

Di `index.html`, isi `CONTACT_EMAIL` pada blok `CONFIG`. Alamat itu otomatis tampil di kaki halaman dan di kebijakan privasi. Jika kosong, bagian kontak disembunyikan.

## Catatan

Teks Kebijakan privasi dan Syarat penggunaan adalah draf berbahasa sederhana, bukan nasihat hukum. Mohon dibaca ulang dan disesuaikan sebelum dipakai untuk umum.
