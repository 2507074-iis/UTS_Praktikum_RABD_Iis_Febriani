-- =====================================================================
-- 03_Transaksi.sql  |  Tugas 3 - Pengelolaan Transaksi (MySQL / InnoDB)
-- =====================================================================
USE electromart;

SELECT id_produk, nama_produk, stok FROM produk
WHERE id_produk IN ('PRD001','PRD002','PRD006','PRD008','PRD009','PRD010') ORDER BY id_produk;

-- =====================================================================
-- SKENARIO A - Transaksi berhasil (1 Laptop + 2 Mouse) -> COMMIT
-- =====================================================================
START TRANSACTION;

  INSERT INTO penjualan (id_penjualan, tanggal, id_pelanggan, id_pegawai, total_harga, diskon, total_bayar)
  VALUES ('TRX005', '2026-11-10 09:30:00', 'PLG005', 'PGW002', 15000000, 1500000, 13500000);

  INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES
  ('TRX005', 'PRD001', 1, 14500000, 14500000),
  ('TRX005', 'PRD002', 2,   250000,   500000);

  UPDATE produk SET stok = stok - 1 WHERE id_produk = 'PRD001';
  UPDATE produk SET stok = stok - 2 WHERE id_produk = 'PRD002';

  INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan) VALUES
  ('PRD001', -1, 'KELUAR', 'Pengurangan stok dari TRX005'),
  ('PRD002', -2, 'KELUAR', 'Pengurangan stok dari TRX005');

COMMIT;

-- Bukti A (PRD001: 15 -> 14, PRD002: 50 -> 48)
SELECT * FROM penjualan WHERE id_penjualan = 'TRX005';
SELECT * FROM detail_penjualan WHERE id_penjualan = 'TRX005';
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD001','PRD002') ORDER BY id_produk;
SELECT * FROM log_stok WHERE keterangan LIKE '%TRX005' ORDER BY id_log;

-- =====================================================================
-- SKENARIO B - Transaksi gagal (jumlah > stok) -> ROLLBACK
-- PRD006 (Smart TV) stok = 2, pelanggan membeli 5 unit.
-- =====================================================================
START TRANSACTION;

  INSERT INTO penjualan (id_penjualan, tanggal, id_pelanggan, id_pegawai, total_harga, diskon, total_bayar)
  VALUES ('TRX006', '2026-11-11 13:00:00', 'PLG001', 'PGW002', 42500000, 4250000, 38250000);

  INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
  VALUES ('TRX006', 'PRD006', 5, 8500000, 42500000);

  UPDATE produk SET stok = stok - 5 WHERE id_produk = 'PRD006';

  -- Di dalam transaksi stok menjadi -3 (tidak valid) -> batalkan
  SELECT id_produk, stok FROM produk WHERE id_produk = 'PRD006';
  SELECT * FROM penjualan WHERE id_penjualan = 'TRX006';

ROLLBACK;

-- Bukti B: stok PRD006 kembali 2, TRX006 dan detailnya tidak ada
SELECT id_produk, stok FROM produk WHERE id_produk = 'PRD006';
SELECT COUNT(*) AS jumlah_trx006        FROM penjualan         WHERE id_penjualan = 'TRX006';  
SELECT COUNT(*) AS jumlah_detail_trx006 FROM detail_penjualan  WHERE id_penjualan = 'TRX006';  
-- =====================================================================
-- SKENARIO C - Pembatalan sebagian (SAVEPOINT)

-- =====================================================================
START TRANSACTION;

  INSERT INTO penjualan (id_penjualan, tanggal, id_pelanggan, id_pegawai)
  VALUES ('TRX007', '2026-11-12 15:20:00', 'PLG003', 'PGW002');

  -- Item 1
  INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
  VALUES ('TRX007', 'PRD008', 4, 85000, 340000);
  UPDATE produk SET stok = stok - 4 WHERE id_produk = 'PRD008';
  INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
  VALUES ('PRD008', -4, 'KELUAR', 'Pengurangan stok dari TRX007');

  SAVEPOINT sp_item_tambahan;

  -- Item 2 (akan dibatalkan)
  INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
  VALUES ('TRX007', 'PRD009', 1, 2400000, 2400000);
  UPDATE produk SET stok = stok - 1 WHERE id_produk = 'PRD009';
  INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
  VALUES ('PRD009', -1, 'KELUAR', 'Pengurangan stok dari TRX007');

  -- Sebelum rollback parsial: 2 baris detail, stok PRD009 = 3
  SELECT id_produk, jumlah FROM detail_penjualan WHERE id_penjualan = 'TRX007';
  SELECT id_produk, stok FROM produk WHERE id_produk = 'PRD009';

  ROLLBACK TO SAVEPOINT sp_item_tambahan;

  -- Sesudah rollback parsial: item 1 tetap ada, item 2 hilang, stok PRD009 = 4
  SELECT id_produk, jumlah FROM detail_penjualan WHERE id_penjualan = 'TRX007';
  SELECT id_produk, stok FROM produk WHERE id_produk = 'PRD009';

  -- Item 3 (pengganti)
  INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
  VALUES ('TRX007', 'PRD010', 1, 950000, 950000);
  UPDATE produk SET stok = stok - 1 WHERE id_produk = 'PRD010';
  INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
  VALUES ('PRD010', -1, 'KELUAR', 'Pengurangan stok dari TRX007');

  RELEASE SAVEPOINT sp_item_tambahan;

  -- 340.000 + 950.000 = 1.290.000 -> diskon 129.000 -> bayar 1.161.000
  UPDATE penjualan
  SET total_harga = 1290000, diskon = 129000, total_bayar = 1161000
  WHERE id_penjualan = 'TRX007';

COMMIT;

-- Bukti C: hanya PRD008 dan PRD010 yang tercatat
SELECT * FROM penjualan WHERE id_penjualan = 'TRX007';
SELECT * FROM detail_penjualan WHERE id_penjualan = 'TRX007' ORDER BY id_detail;
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD008','PRD009','PRD010') ORDER BY id_produk;
SELECT * FROM log_stok WHERE keterangan LIKE '%TRX007' ORDER BY id_log;   

-- Konsistensi: stok tabel = total log (untuk produk yang log-nya lengkap)
SELECT p.id_produk, p.stok AS stok_tabel, SUM(l.jumlah_perubahan) AS stok_menurut_log
FROM produk p JOIN log_stok l ON l.id_produk = p.id_produk
WHERE p.id_produk IN ('PRD001','PRD002','PRD003','PRD004','PRD005','PRD008')
GROUP BY p.id_produk, p.stok ORDER BY p.id_produk;

