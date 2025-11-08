import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class AiSohbetEkrani extends StatefulWidget {
  const AiSohbetEkrani({super.key});

  @override
  State<AiSohbetEkrani> createState() => _AiSohbetEkraniState();
}

class _AiSohbetEkraniState extends State<AiSohbetEkrani> {
  final TextEditingController _mesajController = TextEditingController();
  final List<Map<String, String>> _mesajlar = [];
  bool _isLoading = false;
  bool _useDirectAPI = true; // Direkt API'yi kullan

  // Google Gemini API Key - AYNI KALABİLİR
  static const String API_KEY = "//API KEY";

  // Direkt REST API ile Gemini'ye bağlanma
  Future<String> _geminiDirektAPI(String soru) async {
    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$API_KEY'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "contents": [
            {
              "parts": [
                {"text": "Sen bir diyet ve beslenme asistanısın. Kullanıcılara sağlıklı beslenme, diyet, egzersiz konularında tavsiyeler ver. Asla tıbbi teşhis veya tedavi önerme. Kısa, motive edici ve yardımcı cevaplar ver. Cevapların Türkçe olmalı."}
              ]
            },
            {
              "parts": [
                {"text": soru}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 500,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'] ?? "Cevap alınamadı.";
        } else {
          throw Exception("API cevap formatı beklenenden farklı: ${response.body}");
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      throw Exception("API Hatası: $e");
    }
  }

  // Google Generative AI Paketi ile
  Future<String> _geminiWithPackage(String soru) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: API_KEY,
        generationConfig: GenerationConfig(
          maxOutputTokens: 500,
          temperature: 0.7,
        ),
      );

      final prompt = "Sen bir diyet ve beslenme asistanısın. Kullanıcılara sağlıklı beslenme, diyet, egzersiz konularında tavsiyeler ver. Asla tıbbi teşhis veya tedavi önerme. Kısa, motive edici ve yardımcı cevaplar ver. Cevapların Türkçe olmalı.\n\nKullanıcı: $soru";
      
      final content = Content.text(prompt);
      final response = await model.generateContent([content]);
      
      return response.text ?? "Cevap alınamadı.";
    } catch (e) {
      throw Exception("Paket Hatası: $e");
    }
  }

  Future<void> _mesajGonder() async {
    if (_mesajController.text.isEmpty) return;
    
    final String soru = _mesajController.text;
    _mesajController.clear();

    setState(() {
      _mesajlar.add({'rol': 'kullanici', 'mesaj': soru});
      _isLoading = true;
    });

    try {
      String cevap;
      
      if (_useDirectAPI) {
        cevap = await _geminiDirektAPI(soru);
      } else {
        cevap = await _geminiWithPackage(soru);
      }

      setState(() {
        _mesajlar.add({'rol': 'model', 'mesaj': cevap});
      });
    } catch (e) {
      debugPrint("Hata: $e");
      
      // Hata durumunda diğer yöntemi dene
      if (_useDirectAPI) {
        _useDirectAPI = false;
        _mesajGonder();
        return;
      }
      
      setState(() {
        _mesajlar.add({
          'rol': 'model', 
          'mesaj': "Teknik bir sorun oluştu. Lütfen daha sonra tekrar deneyin. Hata detayı: ${e.toString()}"
        });
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sanal Diyetisyen Asistanı - Gemini AI"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _mesajlar.length,
              itemBuilder: (context, index) {
                final mesaj = _mesajlar[index];
                bool bendenMi = mesaj['rol'] == 'kullanici';
                return Container(
                  alignment: bendenMi ? Alignment.centerRight : Alignment.centerLeft,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bendenMi ? Colors.green[100] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      mesaj['mesaj']!,
                      style: TextStyle(
                        color: bendenMi ? Colors.green[900] : Colors.blue[900],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text("Gemini AI düşünüyor...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
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
              bottom: MediaQuery.of(context).viewInsets.bottom + 8
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mesajController,
                    decoration: InputDecoration(
                      hintText: 'Gemini AI\'ya sağlıklı beslenme hakkında soru sorun...',
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
