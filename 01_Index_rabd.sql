-- =====================================================================
-- 01_Indexing.sql  |  Tugas 1 - Konfigurasi Indexing 
-- =====================================================================

-- ---------- 1. Single-column index ----------
-- Kebutuhan: "cari produk berdasarkan kategori"
CREATE INDEX idx_produk_kategori ON produk (kategori);

-- Kebutuhan: "cari transaksi berdasarkan tanggal" (rentang waktu / laporan)
CREATE INDEX idx_penjualan_tanggal ON penjualan (tanggal);

-- ---------- 2. Composite index ----------
-- Kebutuhan: "cari transaksi berdasarkan pelanggan DAN tanggal"
CREATE INDEX idx_penjualan_pelanggan_tanggal ON penjualan (id_pelanggan, tanggal);

-- ---------- 3. Index pendukung JOIN (opsional, nilai tambah) ----------
-- PostgreSQL TIDAK otomatis membuat index pada kolom foreign key.
CREATE INDEX idx_detail_id_penjualan ON detail_penjualan (id_penjualan);
CREATE INDEX idx_detail_id_produk    ON detail_penjualan (id_produk);

-- ---------- 4. Bukti pemeriksaan index (katalog pg_indexes) ----------
SELECT tablename, indexname, indexdef
FROM   pg_indexes
WHERE  schemaname = 'public'
  AND  tablename IN ('produk','penjualan','detail_penjualan')
ORDER  BY tablename, indexname;

-- ---------- 5. Bukti index dipakai (EXPLAIN) ----------

SET enable_seqscan = off;

EXPLAIN SELECT * FROM produk WHERE kategori = 'Aksesoris';

EXPLAIN SELECT * FROM penjualan
WHERE tanggal BETWEEN '2026-11-01' AND '2026-11-05 23:59:59';

EXPLAIN SELECT * FROM penjualan
WHERE id_pelanggan = 'PLG001' AND tanggal >= '2026-11-01';

-- Composite index TIDAK efektif jika hanya kolom kedua (tanggal) yang dicari,
-- tetapi query ini tetap terlayani oleh idx_penjualan_tanggal.
EXPLAIN SELECT * FROM penjualan WHERE tanggal >= '2026-11-01';

RESET enable_seqscan;

