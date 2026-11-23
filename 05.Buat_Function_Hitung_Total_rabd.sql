CREATE FUNCTION hitung_total(p_harga DECIMAL(12,2), p_jumlah INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN p_harga * p_jumlah;
END;

CREATE FUNCTION hitung_diskon(p_total DECIMAL(12,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    IF p_total >= 1000000 THEN
        RETURN 0.10 * p_total;
    END IF;
    RETURN 0;
END;

CREATE TRIGGER validasi_penjualan
BEFORE INSERT ON detail_penjualan
FOR EACH ROW
BEGIN
    DECLARE v_harga DECIMAL(12,2);
    DECLARE v_stok  INT;
    DECLARE v_ada   INT;
    DECLARE v_pesan VARCHAR(200);
    SELECT COUNT(*) INTO v_ada FROM produk WHERE id_produk = NEW.id_produk;
    IF v_ada = 0 THEN
        SET v_pesan = CONCAT('Produk ', IFNULL(NEW.id_produk,'(kosong)'), ' tidak terdaftar');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_pesan;
    END IF;
    IF NEW.jumlah IS NULL OR NEW.jumlah <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Jumlah pembelian harus lebih besar dari 0';
    END IF;
    SELECT harga, stok INTO v_harga, v_stok
    FROM produk WHERE id_produk = NEW.id_produk FOR UPDATE;
    IF NEW.harga_satuan IS NULL OR NEW.harga_satuan <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Harga satuan harus lebih besar dari 0';
    END IF;
    IF NEW.harga_satuan <> v_harga THEN
        SET v_pesan = CONCAT('Harga satuan tidak sesuai harga produk (', v_harga, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_pesan;
    END IF;
    IF v_stok < NEW.jumlah THEN
        SET v_pesan = CONCAT('Stok tidak mencukupi: tersedia ', v_stok, ', diminta ', NEW.jumlah);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_pesan;
    END IF;
    SET NEW.subtotal = hitung_total(NEW.harga_satuan, NEW.jumlah);
END;

CREATE TRIGGER update_stok_penjualan
AFTER INSERT ON detail_penjualan
FOR EACH ROW
BEGIN
    UPDATE produk SET stok = stok - NEW.jumlah WHERE id_produk = NEW.id_produk;
    INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
    VALUES (NEW.id_produk, -NEW.jumlah, 'KELUAR',
            CONCAT('Pengurangan stok dari ', NEW.id_penjualan));
END;

CREATE TRIGGER hitung_total_penjualan
AFTER INSERT ON detail_penjualan
FOR EACH ROW
BEGIN
    UPDATE penjualan
    SET total_harga = total_harga + NEW.subtotal,
        diskon      = hitung_diskon(total_harga),
        total_bayar = total_harga - diskon
    WHERE id_penjualan = NEW.id_penjualan;
END;

-- =====================================================================
-- 05f_Pengujian_Function_Trigger.sql | Pengujian Tugas 5 (MySQL)
-
-- =====================================================================

-- ---------- 1. Bukti function & trigger terdaftar ----------
-- 2 function
SHOW FUNCTION STATUS WHERE Db = 'electromart';

-- 3 trigger
SHOW TRIGGERS FROM electromart;

-- ---------- 2. Uji function langsung ----------
SELECT hitung_total(14500000, 1) AS total_laptop,
       hitung_total(250000, 2)   AS total_mouse,
       hitung_diskon(999999)     AS diskon_999999,
       hitung_diskon(1000000)    AS diskon_batas,
       hitung_diskon(15000000)   AS diskon_15jt;

-- ---------- 3. Kondisi awal stok ----------
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD002','PRD004','PRD006') ORDER BY id_produk;

-- ---------- 4. VALID - TIDAK memenuhi diskon (2 mouse = 500.000) ----------
INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai) VALUES ('TRX008','PLG001','PGW002');

INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES ('TRX008','PRD002',2,250000,0);

-- Hasil: 500000 | 0 | 500000
SELECT * FROM penjualan WHERE id_penjualan = 'TRX008';

-- Hasil: subtotal terisi otomatis = 500000
SELECT * FROM detail_penjualan WHERE id_penjualan = 'TRX008';

-- ---------- 5. VALID - MEMENUHI diskon (1 monitor = 3.200.000) ----------
INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai) VALUES ('TRX009','PLG002','PGW002');

INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES ('TRX009','PRD004',1,3200000,0);

-- Hasil: 3200000 | 320000 | 2880000
SELECT * FROM penjualan WHERE id_penjualan = 'TRX009';

-- ---------- 6. Bukti stok berkurang otomatis + log tercatat ----------
-- PRD002 berkurang 2, PRD004 berkurang 1 dibanding kondisi awal
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD002','PRD004') ORDER BY id_produk;

SELECT * FROM log_stok WHERE keterangan IN ('Pengurangan stok dari TRX008','Pengurangan stok dari TRX009') ORDER BY id_log;

-- ---------- 7. TIDAK VALID - semua HARUS ERROR 1644 ----------
INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai) VALUES ('TRX010','PLG003','PGW002');

-- HARUS ERROR: Stok tidak mencukupi (stok PRD006 hanya 2)
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES ('TRX010','PRD006',5,8500000,0);

-- HARUS ERROR: Jumlah pembelian harus lebih besar dari 0
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES ('TRX010','PRD002',0,250000,0);

-- HARUS ERROR: Jumlah pembelian harus lebih besar dari 0
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES ('TRX010','PRD002',-3,250000,0);

-- HARUS ERROR: Produk PRD999 tidak terdaftar
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES ('TRX010','PRD999',1,1000,0);

-- HARUS ERROR: Harga satuan tidak sesuai harga produk
INSERT INTO detail_penjualan (id_penjualan, id_produk, jumlah, harga_satuan, subtotal) VALUES ('TRX010','PRD001',1,1000,0);

-- ---------- 8. Bukti penolakan: tidak ada yang berubah ----------
-- Hasil: 0
SELECT COUNT(*) AS detail_trx010 FROM detail_penjualan WHERE id_penjualan = 'TRX010';

-- Hasil: 0 | 0 | 0
SELECT * FROM penjualan WHERE id_penjualan = 'TRX010';

-- Hasil: stok PRD006 tetap 2, PRD001 dan PRD002 tidak berubah karena percobaan gagal
SELECT id_produk, stok FROM produk WHERE id_produk IN ('PRD001','PRD002','PRD006') ORDER BY id_produk;

-- Hasil: 0
SELECT COUNT(*) AS log_trx010 FROM log_stok WHERE keterangan LIKE '%TRX010';

-- Bersihkan header sisa uji
DELETE FROM penjualan WHERE id_penjualan = 'TRX010';

SHOW TRIGGERS FROM electromart;

SELECT id_penjualan FROM penjualan WHERE id_penjualan IN ('TRX008','TRX009','TRX010');