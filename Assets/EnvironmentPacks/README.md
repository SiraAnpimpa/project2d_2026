# OLETHROS Environment Packs

ฉากหลักถูกแบ่งเป็นโมดูลภาพความละเอียด `1254 × 1254 px` และประกอบใน Godot ที่สเกล `1:1` เพื่อรักษาความคมชัด:

- `LandingZone` — 4 โมดูลแบบ 2 × 2
- `CrystalField` — 4 โมดูลเรียงแนวนอน
- `SignalBase` — 3 โมดูลเรียงแนวนอน

Scene สำหรับประกอบแพ็กอยู่ใน `res://Scenes/EnvironmentPacks/` และแต่ละชิ้นใช้ prefab `environment_chunk.tscn`

## การกำหนดทางเดินและกำแพง

เลือก `EnvironmentChunk` ใน Godot Inspector แล้วแก้ค่าต่อไปนี้:

- `Open Edges` — เปิดช่องทางด้าน North / East / South / West
- `Doorway Width` — ความกว้างช่องประตูตรงกลางขอบ
- `Wall Depth` — ความหนาของ collision รอบโมดูล
- `Obstacle Rects` — กำแพงหรือวัตถุทรงสี่เหลี่ยมภายในภาพ (พิกัด local)
- `Obstacle Circles` — วัตถุทรงกลมในรูป `Vector3(x, y, radius)`

ใน Editor จะมี overlay สีแดงแสดงกำแพง สีเขียวแสดงช่องทาง และสีส้มแสดงสิ่งกีดขวาง ส่วน overlay นี้ไม่แสดงตอนเล่นเกม CollisionShape2D จะถูกสร้างอัตโนมัติจากค่าดังกล่าว

เมื่อต่อโมดูล ให้เลื่อนจุดกึ่งกลางครั้งละ `1254 px` และเปิดขอบของทั้งสองชิ้นที่ชนกัน เช่น ชิ้นซ้ายเปิด `East` และชิ้นขวาเปิด `West`

ภาพทั้งหมดนำเข้าแบบ lossless, ปิด mipmaps และแสดงด้วย nearest-neighbor filtering เพื่อไม่ให้ pixel art เบลอ
