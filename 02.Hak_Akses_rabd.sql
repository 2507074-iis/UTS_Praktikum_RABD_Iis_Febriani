-- =====================================================================
-- 02_Hak_Akses.sql  |  Tugas 2 - Hak Akses Berbasis Role (PostgreSQL)


-- ---------- 1. CREATE ROLE (group role, tidak bisa login) ----------
CREATE ROLE role_admin     NOLOGIN;
CREATE ROLE role_penjualan NOLOGIN;
CREATE ROLE role_gudang    NOLOGIN;
CREATE ROLE role_manajer   NOLOGIN;

-- ---------- 2. Akun pengguna (bisa login) + hubungkan ke role ----------
-- Ganti password untuk penggunaan nyata.
CREATE USER user_admin  LOGIN PASSWORD 'Admin#123';   -- PGW001 Andi Wijaya
CREATE USER user_maya   LOGIN PASSWORD 'Sales#123';   -- PGW002 Maya Putri
CREATE USER user_eko    LOGIN PASSWORD 'Gudang#123';  -- PGW003 Eko Prasetyo
CREATE USER user_hendra LOGIN PASSWORD 'Manajer#123'; -- PGW004 Hendra Gunawan

GRANT role_admin     TO user_admin;
GRANT role_penjualan TO user_maya;
GRANT role_gudang    TO user_eko;
GRANT role_manajer   TO user_hendra;

-- ---------- 3. Dasar: akses schema ----------
REVOKE CREATE ON SCHEMA public FROM PUBLIC;   -- (PG < 15: PUBLIC boleh CREATE)
GRANT  USAGE  ON SCHEMA public TO role_admin, role_penjualan, role_gudang, role_manajer;
GRANT  CREATE ON SCHEMA public TO role_admin;

-- ---------- 4. role_admin: kelola seluruh objek ----------
-- Memindahkan kepemilikan tabel ke role_admin supaya bisa ALTER/DROP.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I OWNER TO role_admin', r.tablename);
  END LOOP;
END $$;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO role_admin;

-- ---------- 5. role_penjualan: lihat produk & pelanggan, input transaksi ----------
GRANT SELECT          ON produk, pelanggan TO role_penjualan;
GRANT SELECT, INSERT, UPDATE ON penjualan  TO role_penjualan;   -- UPDATE sengaja dicabut di bawah
GRANT SELECT, INSERT  ON detail_penjualan  TO role_penjualan;
GRANT USAGE ON SEQUENCE detail_penjualan_id_detail_seq TO role_penjualan;
-- TIDAK ada akses ke log_stok dan tidak ada UPDATE pada produk.

-- REVOKE: transaksi yang sudah dicatat tidak boleh diubah oleh kasir
REVOKE UPDATE ON penjualan FROM role_penjualan;

-- ---------- 6. role_gudang: lihat produk, perbarui stok ----------
GRANT SELECT ON produk TO role_gudang;
GRANT UPDATE (stok) ON produk TO role_gudang;            -- hanya kolom stok (column-level)
GRANT SELECT, INSERT ON log_stok TO role_gudang;         -- mencatat barang masuk
GRANT USAGE ON SEQUENCE log_stok_id_log_seq TO role_gudang;

-- ---------- 7. role_manajer: lihat produk & laporan penjualan (read-only) ----------
GRANT SELECT ON produk, penjualan, detail_penjualan TO role_manajer;

-- ---------- 8. Bukti konfigurasi ----------
SELECT rolname, rolcanlogin FROM pg_roles
WHERE rolname LIKE 'role\_%' OR rolname LIKE 'user\_%' ORDER BY rolcanlogin, rolname;

SELECT r.rolname AS "member", g.rolname AS "anggota_dari_role"
FROM pg_auth_members m
JOIN pg_roles r ON r.oid = m.member
JOIN pg_roles g ON g.oid = m.roleid
WHERE g.rolname LIKE 'role\_%' ORDER BY 1;

SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee LIKE 'role\_%' AND table_schema = 'public' AND grantee <> 'role_admin'
ORDER BY grantee, table_name, privilege_type;



-- =====================================================================
-- 9. PENGUJIAN AKSES
-- =====================================================================

-- ---------- 9a. user_maya (role_penjualan) ----------
SET ROLE user_maya;
SELECT current_user;
SELECT * FROM produk;                                   
SELECT * FROM pelanggan;                                

START TRANSACTION;                                       
  INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai)
  VALUES ('TRX900', 'PLG001', 'PGW002');
ROLLBACK;

ALTER TABLE produk ADD COLUMN garansi INT;               
SELECT * FROM log_stok;                                 
UPDATE produk SET harga = 1 WHERE id_produk = 'PRD001'; 
UPDATE penjualan SET diskon = 0;                        
DELETE FROM penjualan;                                  
RESET ROLE;

-- ---------- 9b. user_eko (role_gudang) ----------
SET ROLE user_eko;
SELECT id_produk, nama_produk, stok FROM produk;        

START TRANSACTION;                                      
  UPDATE produk SET stok = stok + 5 WHERE id_produk = 'PRD003';
  INSERT INTO log_stok (id_produk, jumlah_perubahan, tipe_transaksi, keterangan)
  VALUES ('PRD003', 5, 'MASUK', 'Uji role gudang');
  SELECT id_produk, stok FROM produk WHERE id_produk = 'PRD003';
ROLLBACK;

UPDATE produk SET harga = 1 WHERE id_produk = 'PRD003'; 
SELECT * FROM penjualan;                                
SELECT * FROM pelanggan;                                
DELETE FROM produk;                                    
RESET ROLE;

-- ---------- 9c. user_hendra (role_manajer) ----------
SET ROLE user_hendra;
SELECT * FROM produk;                                   
SELECT * FROM penjualan;                               
SELECT p.id_penjualan, d.id_produk, d.jumlah, d.subtotal
FROM penjualan p JOIN detail_penjualan d USING (id_penjualan);  

INSERT INTO penjualan (id_penjualan, id_pelanggan, id_pegawai)
VALUES ('TRX901', 'PLG001', 'PGW004');                  
UPDATE produk SET stok = 0;                            
SELECT * FROM log_stok;                                 
SELECT * FROM pelanggan;                                
RESET ROLE;

-- ---------- 9d. user_admin (role_admin) ----------
SET ROLE user_admin;
ALTER TABLE produk ADD COLUMN garansi_bulan INT;        -- BERHASIL
ALTER TABLE produk DROP COLUMN garansi_bulan;           -- BERHASIL (dikembalikan)
SELECT COUNT(*) FROM log_stok;                          -- BERHASIL
RESET ROLE;

-- ---------- 9e. Pemeriksaan tanpa error  ----------
SELECT u.usr,
       has_table_privilege(u.usr, 'produk',           'SELECT') AS lihat_produk,
       has_table_privilege(u.usr, 'produk',           'UPDATE') AS ubah_produk,
       has_table_privilege(u.usr, 'penjualan',        'INSERT') AS input_penjualan,
       has_table_privilege(u.usr, 'log_stok',         'SELECT') AS lihat_log_stok,
       has_column_privilege(u.usr,'produk','stok',    'UPDATE') AS ubah_stok
FROM (VALUES ('user_admin'),('user_maya'),('user_eko'),('user_hendra')) AS u(usr);

