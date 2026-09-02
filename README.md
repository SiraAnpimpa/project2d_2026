# OLETHROS // ZONE-67

โปรเจกต์เกม 2D แนว sci-fi survival/exploration พัฒนาด้วย Godot 4.7 ผู้เล่นต้องสำรวจดาว Zone-67 เก็บชิ้นส่วนยาน เอาตัวรอดจากสิ่งมีชีวิตต่างดาว และค้นหาต้นกำเนิดของสัญญาณลึกลับ

## เล่นบนเว็บ

[เปิดเกม OLETHROS // ZONE-67](https://siraanpimpa.github.io/project2d_2026/)

<img src="docs/index.png" alt="OLETHROS // ZONE-67" width="720" />

> หาก GitHub Pages ยังไม่เปิดใช้งาน ให้ตั้งค่า **Settings → Pages → Deploy from a branch → `main` / `docs`**

## การควบคุม

| ปุ่ม | การทำงาน |
|---|---|
| `WASD` / ปุ่มลูกศร | เคลื่อนที่ |
| `E` | โต้ตอบ |
| `Enter` / คลิก | เลือกเมนูและอ่านข้อความต่อ |

## แผนที่

- Landing Zone
- Crystal Field
- Abandoned Signal Base

ขอบเขตที่เดินผ่านได้และไม่ได้แก้ไขได้จาก `CollisionPolygon2D` ภายใต้ `ManualCollision` ในแต่ละฉากของโฟลเดอร์ `Scenes/Levels` โดยใช้เครื่องมือวาด Polygon ใน Godot Editor

## เปิดโปรเจกต์

1. เปิดโฟลเดอร์โปรเจกต์ด้วย Godot 4.7 หรือใหม่กว่า
2. กด `F5` เพื่อเริ่มเกมจากฉากหลัก

## อัปเดตเกมบนเว็บ

หลังแก้เกม ให้ Export preset **Web** ไปที่ `docs/index.html` แล้ว commit ไฟล์ที่เปลี่ยนใน `docs/` ขึ้น GitHub มิฉะนั้นหน้าเว็บจะยังเปิดเกมจาก Web export เวอร์ชันเดิม

ตัวอย่างคำสั่ง:

```powershell
Godot_v4.7-stable_win64.exe --headless --path . --export-release Web docs/index.html
```

## Credits

โปรเจกต์ตั้งต้นสำหรับรายวิชา Computer Game Development, College of Computing, Khon Kaen University และได้รับการพัฒนาต่อเป็น OLETHROS // ZONE-67
