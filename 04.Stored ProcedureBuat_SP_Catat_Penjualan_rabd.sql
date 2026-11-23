CREATE PROCEDURE SP_Catat_Penjualan(
    IN p_id_penjualan VARCHAR(10),
    IN p_id_pelanggan VARCHAR(10),
    IN p_id_pegawai   VARCHAR(10),
    IN p_id_produk    VARCHAR(10),
    IN p_jumlah       INT
)
BEGIN
    DECLARE v_harga DECIMAL(12,2);
    SELECT harga INTO v_harga FROM produk WHERE id_produk = p_id_produk;
    IF v_harga IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Produk tidak terdaftar';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM penjualan WHERE id_penjualan = p_id_penjualan) THEN
        INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai)
        VALUES (p_id_penjualan, p_id_pelanggan, p_id_pegawai);
    END IF;
    INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal)
    VALUES (p_id_penjualan, p_id_produk, p_jumlah, v_harga, 0);
END;

-- =====================================================================
-- 07b_Pengujian_Integrasi.sql | Proses bisnis terpadu 
-- =====================================================================

-- ---------- 0. Pemeriksaan awal ----------
-- Harus ada SP_Catat_Penjualan (total 4 procedure)
SHOW PROCEDURE STATUS WHERE Db = 'electromart';

-- Pegawai yang melayani dan perannya (pengganti pemeriksaan hak akses di sisi MySQL)
SELECT id_pegawai, nama_pegawai, peran FROM pegawai WHERE id_pegawai = 'PGW002';

-- Stok SEBELUM (PRD003 = 3, PRD009 = 4)
SELECT id_produk, nama_produk, stok FROM produk WHERE id_produk IN ('PRD003','PRD009') ORDER BY id_produk;

-- ---------- 1. Transaksi BERHASIL (Langkah 3 + 4 + 5) ----------
START TRANSACTION;

CALL SP_Catat_Penjualan('TRX011', 'PLG005', 'PGW002', 'PRD003', 1);

CALL SP_Catat_Penjualan('TRX011', 'PLG005', 'PGW002', 'PRD009', 2);

COMMIT;

-- Hasil: 6000000 | 600000 | 5400000
SELECT * FROM penjualan WHERE id_penjualan = 'TRX011';

-- Hasil: 2 baris detail, subtotal terisi trigger
SELECT * FROM detail_penjualan WHERE id_penjualan = 'TRX011' ORDER BY id_detail;

-- Stok SESUDAH (PRD003 = 2, PRD009 = 2)
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD003','PRD009') ORDER BY id_produk;

-- Log stok otomatis: 2 baris KELUAR
SELECT * FROM log_stok WHERE keterangan LIKE '%TRX011' ORDER BY id_log;

-- ---------- 2. Transaksi GAGAL lalu ROLLBACK ----------
START TRANSACTION;


CALL SP_Catat_Penjualan('TRX012', 'PLG005', 'PGW002', 'PRD006', 5);

ROLLBACK;

-- Hasil: hanya TRX011 (TRX012 tidak ada), stok PRD006 tetap 2
SELECT id_penjualan FROM penjualan WHERE id_penjualan IN ('TRX011','TRX012');

SELECT id_produk, stok FROM produk WHERE id_produk = 'PRD006';

-- ---------- 3. Manajemen melihat laporan lewat View (Langkah 6) ----------
SELECT * FROM View_Transaksi WHERE id_penjualan = 'TRX011';

SELECT * FROM View_Laporan_Penjualan ORDER BY periode, kategori;

SELECT * FROM View_Stok_Rendah ORDER BY stok;