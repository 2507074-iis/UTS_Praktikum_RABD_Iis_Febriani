

DO $$
DECLARE
    r TEXT;
BEGIN
    -- 1. Kembalikan kepemilikan objek milik role_admin ke user saat ini
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_admin') THEN
        EXECUTE format('REASSIGN OWNED BY role_admin TO %I', current_user);
    END IF;

    -- 2. Cabut semua hak yang pernah diberikan ke role/user tersebut
    FOR r IN SELECT rolname FROM pg_roles
             WHERE rolname IN ('user_admin','user_maya','user_eko','user_hendra',
                               'role_admin','role_penjualan','role_gudang','role_manajer')
    LOOP
        EXECUTE format('DROP OWNED BY %I', r);
    END LOOP;

    -- 3. Hapus role dan user
    FOR r IN SELECT rolname FROM pg_roles
             WHERE rolname IN ('user_admin','user_maya','user_eko','user_hendra',
                               'role_admin','role_penjualan','role_gudang','role_manajer')
    LOOP
        EXECUTE format('DROP ROLE %I', r);
    END LOOP;
END $$;

-- Bukti reset berhasil: harus 0 baris
SELECT rolname FROM pg_roles
WHERE rolname LIKE 'role\_%' OR rolname LIKE 'user\_%';

-- Bukti data tetap utuh: 10 produk, pemilik tabel kembali ke postgres
SELECT tablename, tableowner FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
SELECT COUNT(*) AS jumlah_produk FROM produk;
