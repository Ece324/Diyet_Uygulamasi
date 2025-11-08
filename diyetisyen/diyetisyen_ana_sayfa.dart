import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../giris/login_screen.dart';
import '../kullanici/mesajlasma_ekrani.dart';

class DiyetisyenAnaSayfa extends StatefulWidget {
  final String diyetisyenId;
  final String diyetisyenAdi;

  const DiyetisyenAnaSayfa({
    super.key,
    required this.diyetisyenId,
    required this.diyetisyenAdi,
  });

  @override
  State<DiyetisyenAnaSayfa> createState() => _DiyetisyenAnaSayfaState();
}

class _DiyetisyenAnaSayfaState extends State<DiyetisyenAnaSayfa> {
  // YENİ: Stream'i initState içinde başlatmak daha güvenli
  late final Stream<QuerySnapshot> _sohbetlerStream;
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _sohbetlerStream = FirebaseFirestore.instance
          .collection('sohbetler')
          .where('katilimcilar', arrayContains: _currentUser!.uid)
          // YENİ: Sohbetleri son mesaj tarihine göre sırala (opsiyonel ama önerilir)
          .orderBy('sonMesajTarihi', descending: true)
          .snapshots();
    } else {
      _sohbetlerStream = Stream.empty(); // Kullanıcı yoksa boş stream
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Diyetisyen Paneli"),
        actions: [ /* Çıkış yap butonu aynı */
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Çıkış Yap",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Hoş geldin, ${widget.diyetisyenAdi}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              "Aktif Danışan Sohbetleri",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _sohbetlerStream, // initState'de tanımlanan stream'i kullan
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Hata: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("Henüz aktif bir sohbetiniz yok."),
                  );
                }

                final sohbetler = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: sohbetler.length,
                  itemBuilder: (context, index) {
                    final sohbet = sohbetler[index];
                    final data = sohbet.data() as Map<String, dynamic>;
                    final katilimcilar =
                        List<String>.from(data['katilimcilar'] ?? []);
                    final katilimciAdlari =
                        Map<String, String>.from(data['katilimciAdlari'] ?? {});

                    // Danışanın ID'sini ve adını bul
                    final danisanId = katilimcilar.firstWhere(
                        (id) => id != _currentUser!.uid,
                        orElse: () => '');
                    // YENİ: Daha güvenli ad alma
                    final danisanAdi = katilimciAdlari[danisanId] ?? "Bilinmeyen Danışan";
                    final sonMesaj = data['sonMesaj'] as String? ?? ''; // Son mesajı al

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6), // Biraz daha sıkı
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        title: Text(danisanAdi, style: TextStyle(fontWeight: FontWeight.bold)),
                        // YENİ: Son mesajı göster (varsa)
                        subtitle: Text(
                          sonMesaj,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16), // Daha küçük ikon
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MesajlasmaEkrani(
                                sohbetOdasiId: sohbet.id,
                                hedefKullaniciAdi: danisanAdi,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

