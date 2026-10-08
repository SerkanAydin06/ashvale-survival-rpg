# Ashvale — 3D Survival RPG Prototype

Godot 4 için Meshy karakterli, üçüncü şahıs kamera ve hareket test sahnesi.

## Açılış
1. Godot 4.3+ açın.
2. **Import** ile bu klasördeki `project.godot` dosyasını seçin.
3. GLB importu bitince F6 veya F5 ile oyunu çalıştırın.

## Kontroller
- **WASD** hareket
- **Mouse** kamera
- **Shift** koş
- **Space** zıpla
- **Esc** fareyi serbest bırak / geri yakala

## Mevcut içerik
- Meshy'den gelen rigli karakter GLB (`Running` animasyonu)
- `Running` klibi hareket halinde hızlandırılarak veya yavaşlatılarak oynatılır
- Sabit boyutlu test alanı, ağaçlar, taşlar, sandıklar
- Üçüncü şahıs takip kamerası
- Basit HUD

## Sınırlar
- Bu **oynanış prototipi**. Henüz dövüş, loot, crafting veya save sistemi yok.
- GLB içinde yalnızca `Running` olduğundan idle pozu sabittir ve yürüyüş için koşma klibi yavaşlatılır.
- Mevcut Meshy skinning/eklem bozulmaları korunur; bu prototip bunları düzeltmez.
- GitHub Actions veya otomatik CI yok.
- GLB dosyası Meshy'den üretilmiş kullanıcı varlığıdır.
