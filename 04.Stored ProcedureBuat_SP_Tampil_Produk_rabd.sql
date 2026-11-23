DROP PROCEDURE IF EXISTS SP_Tampil_Produk;
DROP PROCEDURE IF EXISTS SP_Tambah_Produk;
DROP PROCEDURE IF EXISTS SP_Ubah_Harga;
SHOW PROCEDURE STATUS WHERE Db = 'electromart';

CREATE PROCEDURE SP_Tampil_Produk()
BEGIN
    SELECT id_produk, nama_produk, kategori, harga, stok
    FROM produk
    ORDER BY id_produk;
END;

