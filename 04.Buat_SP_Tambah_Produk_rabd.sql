CREATE PROCEDURE SP_Tambah_Produk(
    IN p_id_produk   VARCHAR(10),
    IN p_nama_produk VARCHAR(100),
    IN p_kategori    VARCHAR(50),
    IN p_harga       DECIMAL(12,2),
    IN p_stok        INT
)
BEGIN
    IF p_harga IS NULL OR p_harga <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Harga harus lebih besar dari 0';
    END IF;
    IF p_stok IS NULL OR p_stok < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stok awal tidak boleh negatif';
    END IF;
    IF EXISTS (SELECT 1 FROM produk WHERE id_produk = p_id_produk) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ID produk sudah terdaftar';
    END IF;
    INSERT INTO produk (id_produk, nama_produk, kategori, harga, stok)
    VALUES (p_id_produk, p_nama_produk, p_kategori, p_harga, p_stok);
    IF p_stok > 0 THEN
        INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
        VALUES (p_id_produk, p_stok, 'MASUK', 'Stok awal produk baru');
    END IF;
END;

CREATE PROCEDURE SP_Ubah_Harga(
    IN p_id_produk  VARCHAR(10),
    IN p_harga_baru DECIMAL(12,2)
)
BEGIN
    IF p_harga_baru IS NULL OR p_harga_baru <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Harga baru harus lebih besar dari 0';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM produk WHERE id_produk = p_id_produk) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Produk tidak ditemukan';
    END IF;
    UPDATE produk SET harga = p_harga_baru WHERE id_produk = p_id_produk;
END;

SHOW PROCEDURE STATUS WHERE Db = 'electromart';

-- =====================================================================
-- 04d_Pengujian_Procedure.sql | Pengujian Tugas 4 (MySQL)

-- =====================================================================

-- ---------- 1. Bukti 3 procedure terdaftar (hasil: 3 baris) ----------
SHOW PROCEDURE STATUS WHERE Db = 'electromart';

-- ---------- 2. SP_Tampil_Produk (hasil: 10 produk) ----------
CALL SP_Tampil_Produk();

-- ---------- 3. SP_Tambah_Produk: dua data berbeda ----------
CALL SP_Tambah_Produk('PRD011', 'Speaker JBL Flip 6', 'Audio', 1899000, 20);

CALL SP_Tambah_Produk('PRD012', 'Kabel HDMI 2m', 'Aksesoris', 75000, 0);

-- Bukti: 2 produk baru
SELECT * FROM produk WHERE id_produk IN ('PRD011','PRD012');

-- Bukti: log MASUK 20 untuk PRD011
SELECT * FROM log_stok WHERE id_produk = 'PRD011';

-- ---------- 4. SP_Ubah_Harga: dua data berbeda ----------
-- SEBELUM
SELECT id_produk, nama_produk, harga FROM produk WHERE id_produk IN ('PRD010','PRD011');

CALL SP_Ubah_Harga('PRD010', 975000);

CALL SP_Ubah_Harga('PRD011', 1799000);

-- SESUDAH (PRD010 = 975000, PRD011 = 1799000)
SELECT id_produk, nama_produk, harga FROM produk WHERE id_produk IN ('PRD010','PRD011');

-- ---------- 5. Uji validasi: tiap statement HARUS ERROR 1644 ----------
CALL SP_Tambah_Produk('PRD011', 'Duplikat', 'Audio', 100000, 1);   -- ID produk sudah terdaftar

CALL SP_Tambah_Produk('PRD013', 'Harga Nol', 'Audio', 0, 1);       -- Harga harus lebih besar dari 0

CALL SP_Ubah_Harga('PRD999', 100000);                              -- Produk tidak ditemukan

CALL SP_Ubah_Harga('PRD010', -5);                                  -- Harga baru harus lebih besar dari 0

-- ---------- 6. DROP PROCEDURE ----------
-- 6a. SELEKSI blok di bawah (dari CREATE sampai END;) lalu Ctrl+Enter
CREATE PROCEDURE SP_Contoh_Hapus()
BEGIN
    SELECT 'procedure sementara' AS info;
END;

-- 6b.
CALL SP_Contoh_Hapus();

-- 6c.
DROP PROCEDURE SP_Contoh_Hapus;

-- 6d. Bukti terhapus: hasil 0 baris
SELECT ROUTINE_NAME FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'electromart' AND ROUTINE_NAME = 'SP_Contoh_Hapus';

-- 6e. Tiga procedure utama tetap ada (hasil: 3 baris)
SHOW PROCEDURE STATUS WHERE Db = 'electromart';