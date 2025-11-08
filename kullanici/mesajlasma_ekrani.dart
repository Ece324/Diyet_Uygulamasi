// lib/kullanici/mesajlasma_ekrani.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MesajlasmaEkrani extends StatefulWidget {
  // Diyetisyen listesinden gelirken bu ikisi dolu olacak
  final String? diyetisyenId;
  final String? diyetisyenAdi;

  // Diyetisyen panelinden (sohbet listesinden) gelirken bu ikisi dolu olacak
  final String? sohbetOdasiId;
  final String? hedefKullaniciAdi; // (Danışanın adı)

  const MesajlasmaEkrani({
    super.key,
    this.diyetisyenId,
    this.diyetisyenAdi,
    this.sohbetOdasiId,
    this.hedefKullaniciAdi,
  });

  @override
  State<MesajlasmaEkrani> createState() => _MesajlasmaEkraniState();
}

class _MesajlasmaEkraniState extends State<MesajlasmaEkrani> {
  final _mesajController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;

  // YENİ: Gerekli state değişkenleri
  late String _chatRoomId;
  late String _hedefKullaniciAdi; // AppBar'da gösterilecek ad
  String _currentUserAdSoyad = 'Kullanıcı'; // Giriş yapan kullanıcının adı

  @override
  void initState() {
    super.initState();
    _chatRoomId = _getChatRoomId();
    _hedefKullaniciAdi = _getHedefKullaniciAdi();
    // YENİ: Mesaj göndermeden önce mevcut kullanıcının adını al
    _kullaniciAdiniGetir();
  }

  // YENİ: Mevcut kullanıcının adını Firestore'dan çek
  Future<void> _kullaniciAdiniGetir() async {
    if (_currentUser == null) return;
    try {
      final userDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserAdSoyad = userDoc.data()?['adSoyad'] ?? 'Kullanıcı';
        });
      }
    } catch (e) {
      debugPrint("Kullanıcı adı alınırken hata: $e");
    }
  }

  String _getChatRoomId() {
    // 1. Öncelik: Sohbet listesinden geliyorsa (Diyetisyen)
    if (widget.sohbetOdasiId != null) {
      return widget.sohbetOdasiId!;
    }

    // 2. Öncelik: Diyetisyen listesinden geliyorsa (Danışan)
    if (widget.diyetisyenId != null && _currentUser != null) {
      List<String> ids = [_currentUser!.uid, widget.diyetisyenId!];
      ids.sort(); // Tutarlılık için ID'leri sırala
      return '${ids[0]}_${ids[1]}';
    }
    
    // Geçersiz durum
    debugPrint("HATA: Sohbet odası ID'si oluşturulamadı.");
    return 'hata_odasi';
  }

  String _getHedefKullaniciAdi() {
    // 1. Öncelik: Sohbet listesinden geliyorsa (Diyetisyen)
    if (widget.hedefKullaniciAdi != null) {
      return widget.hedefKullaniciAdi!;
    }
    // 2. Öncelik: Diyetisyen listesinden geliyorsa (Danışan)
    if (widget.diyetisyenAdi != null) {
      return widget.diyetisyenAdi!;
    }
    return 'Kullanıcı';
  }

  void _mesajGonder() async {
    if (_mesajController.text.trim().isEmpty || _currentUser == null) {
      return;
    }

    final messageText = _mesajController.text.trim();
    _mesajController.clear();
    FocusScope.of(context).unfocus(); // Klavyeyi kapat

    try {
      // ChatRoomId zaten initState'de hesaplandı
      if (_chatRoomId == 'hata_odasi') {
        throw Exception('Sohbet odası IDsi bulunamadı');
      }

      // YENİ: Sohbet odası ana dökümanını oluştur/güncelle
      // Bu döküman diyetisyenin listesinde görünecek
      final chatRoomDocRef = _firestore.collection('sohbetler').doc(_chatRoomId);

      // Hedef (diyetisyen) ID'sini bulmamız lazım
      // Eğer diyetisyen listesinden geliyorsak widget.diyetisyenId bellidir.
      // Eğer diyetisyen panelinden geliyorsak, ID'yi chatRoomId'den çıkarmalıyız.
      String hedefId;
      if (widget.diyetisyenId != null) {
        hedefId = widget.diyetisyenId!;
      } else {
        // ID'leri ayır ve mevcut kullanıcı olmayan ID'yi bul
        List<String> ids = _chatRoomId.split('_');
        hedefId = ids.firstWhere((id) => id != _currentUser!.uid, orElse: () => '');
      }

      if (hedefId.isEmpty) {
         throw Exception('Hedef kullanıcı IDsi bulunamadı');
      }

      await chatRoomDocRef.set({
        'katilimcilar': [_currentUser!.uid, hedefId],
        'katilimciAdlari': {
          _currentUser!.uid: _currentUserAdSoyad,
          hedefId: _hedefKullaniciAdi, // AppBar'daki adı kullan
        },
        'sonMesaj': messageText,
        'sonMesajGonderen': _currentUserAdSoyad,
        'sonMesajTarihi': Timestamp.now(),
        'olusturulmaTarihi': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge:true olmalı ki olusturulmaTarihi ezilmesin

      // Mesajı alt koleksiyona gönder
      await chatRoomDocRef.collection('mesajlar').add({
        'text': messageText,
        'gonderenId': _currentUser!.uid,
        'gonderenAdi': _currentUserAdSoyad, // İsmi de kaydet
        'tarih': Timestamp.now(),
      });

      print("Mesaj başarıyla gönderildi: $messageText");
    } catch (e) {
      print("Mesaj gönderme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Mesaj gönderilemedi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_hedefKullaniciAdi)),
        body: const Center(
          child: Text("Lütfen giriş yapın"),
        ),
      );
    }
    
    // chatRoomId artık state'den geliyor
    // final chatRoomId = _getChatRoomId(); 

    return Scaffold(
      appBar: AppBar(
        title: Text(_hedefKullaniciAdi),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('sohbetler')
                  .doc(_chatRoomId)
                  .collection('mesajlar')
                  .orderBy('tarih', descending: false) // Eskiden yeniye sırala
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Hata: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("Henüz mesaj yok"),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: false, // Mesajları aşağıya doğru listele
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final isMe = data['gonderenId'] == _currentUser!.uid;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              // Mesaj kutusu çok genişlemesin
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.green[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(data['text'] ?? ''),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Mesaj gönderme alanı
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                 BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                )
              ]
            ),
            padding: EdgeInsets.only(
              left: 16, 
              right: 8, 
              top: 8, 
              // Klavyenin kapattığı alanı hesaba kat
              bottom: MediaQuery.of(context).padding.bottom + 8
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mesajController,
                    decoration: InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16)
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _mesajGonder(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.green,
                  onPressed: _mesajGonder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}