StatusBarHide

Isi proyek:
- Tweak.xm, Makefile, control, StatusBarHide.plist  (tweak utama)
- statusbarhideprefs/  (halaman pengaturan: saklar + daftar aplikasi)
- layout/  (entri PreferenceLoader agar muncul di Pengaturan)
- .github/workflows/build.yml  (build otomatis di GitHub)

Wajib terpasang di iPhone: PreferenceLoader (dari Sileo).
Hapus SafeAreaFix dari Sileo sebelum memasang paket ini.
Rootful? Hapus baris THEOS_PACKAGE_SCHEME di KEDUA Makefile dan ganti
Architecture di control menjadi iphoneos-arm.
