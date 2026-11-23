-- =====================================================================
-- 06a_Buat_View.sql | Membuat 5 view (MySQL)
-- =====================================================================
USE electromart;

-- 1. View satu tabel: View_Produk (stok eksak disembunyikan)
CREATE OR REPLACE VIEW View_Produk AS
SELECT id_produk, nama_produk, kategori, harga,
       CASE WHEN stok = 0 THEN 'Habis'
            WHEN stok < 5 THEN 'Menipis'
            ELSE 'Tersedia' END AS status_stok
FROM produk;

-- 2. View JOIN: View_Transaksi (transaksi + nama pelanggan + kasir)
CREATE OR REPLACE VIEW View_Transaksi AS
SELECT p.id_penjualan, p.tanggal, pl.nama_pelanggan, pg.nama_pegawai AS kasir,
       p.total_harga, p.diskon, p.total_bayar
FROM penjualan p
LEFT JOIN pelanggan pl ON pl.id_pelanggan = p.id_pelanggan
LEFT JOIN pegawai   pg ON pg.id_pegawai   = p.id_pegawai;

-- 3. View agregasi: View_Laporan_Penjualan (per periode dan kategori)
CREATE OR REPLACE VIEW View_Laporan_Penjualan AS
SELECT DATE_FORMAT(p.tanggal, '%Y-%m') AS periode,
       pr.kategori,
       COUNT(DISTINCT p.id_penjualan) AS jumlah_transaksi,
       SUM(d.jumlah)                  AS unit_terjual,
       SUM(d.subtotal)                AS total_penjualan
FROM penjualan p
JOIN detail_penjualan d ON d.id_penjualan = p.id_penjualan
JOIN produk pr          ON pr.id_produk   = d.id_produk
GROUP BY DATE_FORMAT(p.tanggal, '%Y-%m'), pr.kategori;

-- 4. View stok rendah (batas: stok < 5)
CREATE OR REPLACE VIEW View_Stok_Rendah AS
SELECT id_produk, nama_produk, kategori, stok
FROM produk
WHERE stok < 5;

-- 5. View dengan WITH CHECK OPTION (hanya kategori Aksesoris)
CREATE OR REPLACE VIEW View_Produk_Aksesoris AS
SELECT id_produk, nama_produk, kategori, harga, stok
FROM produk
WHERE kategori = 'Aksesoris'
WITH CHECK OPTION;

-- Bukti: 5 view terbuat
SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'electromart' ORDER BY TABLE_NAME;

-- =====================================================================
-- 06b_Pengujian_View.sql | Pengujian Tugas 6 (MySQL)

-- =====================================================================

-- ---------- 1. Uji SELECT tiap view ----------
-- View satu tabel
SELECT * FROM View_Produk ORDER BY id_produk;

-- View JOIN (nama pelanggan dan kasir muncul)
SELECT * FROM View_Transaksi ORDER BY tanggal;

-- View agregasi (COUNT, SUM, GROUP BY)
SELECT * FROM View_Laporan_Penjualan ORDER BY periode, kategori;

-- Filter per periode
SELECT * FROM View_Laporan_Penjualan WHERE periode = '2026-11' ORDER BY total_penjualan DESC;

-- Total penjualan per bulan dari view yang sama
SELECT periode, SUM(total_penjualan) AS total_bulan FROM View_Laporan_Penjualan GROUP BY periode ORDER BY periode;

-- View stok rendah
SELECT * FROM View_Stok_Rendah ORDER BY stok;

-- ---------- 2. WITH CHECK OPTION ----------
-- VALID: kategori Aksesoris memenuhi kondisi view
INSERT INTO View_Produk_Aksesoris (id_produk, nama_produk, kategori, harga, stok) VALUES ('PRD020', 'Mousepad XL', 'Aksesoris', 120000, 30);

UPDATE View_Produk_Aksesoris SET harga = 135000 WHERE id_produk = 'PRD020';

-- HARUS ERROR 1369 (CHECK OPTION failed): kategori Laptop tidak memenuhi kondisi view
INSERT INTO View_Produk_Aksesoris (id_produk, nama_produk, kategori, harga, stok) VALUES ('PRD021', 'Laptop Uji', 'Laptop', 9000000, 1);

-- HARUS ERROR 1369 (CHECK OPTION failed): mengubah kategori keluar dari kondisi view
UPDATE View_Produk_Aksesoris SET kategori = 'Laptop' WHERE id_produk = 'PRD020';

-- Bukti: hanya PRD020 (Aksesoris) yang masuk, PRD021 tidak ada
SELECT * FROM produk WHERE id_produk IN ('PRD020','PRD021');

-- Bersihkan data uji
DELETE FROM produk WHERE id_produk = 'PRD020';

-- ---------- 3. DROP VIEW ----------
CREATE VIEW View_Produk_Mahal AS SELECT id_produk, nama_produk, harga FROM produk WHERE harga >= 5000000;

SELECT * FROM View_Produk_Mahal;

DROP VIEW View_Produk_Mahal;

-- HARUS ERROR 1146 (view sudah tidak ada)
SELECT * FROM View_Produk_Mahal;

-- Bukti: tersisa 5 view
SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'electromart' ORDER BY TABLE_NAME;


