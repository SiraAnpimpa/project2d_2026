# OLETHROS

โปรเจกต์เกม 2D แนว sci-fi survival/exploration พัฒนาด้วย Godot 4.7 ผู้เล่นต้องสำรวจดาว Zone-67 เก็บชิ้นส่วนยาน เอาตัวรอดจากสิ่งมีชีวิตต่างดาว และค้นหาต้นกำเนิดของสัญญาณลึกลับ

## เล่นบนเว็บ

[เปิดเกม OLETHROS](https://siraanpimpa.github.io/project2d_2026/)

<img src="docs/index.png" alt="OLETHROS // ZONE-67" width="720" />

## การควบคุม

| ปุ่ม | การทำงาน |
|---|---|
| `WASD` / ปุ่มลูกศร | เคลื่อนที่ |
| `E` | โต้ตอบ |
| เมาส์ซ้ายค้าง | เล็งตามเคอร์เซอร์และยิง Pulse Rifle แบบ 360° |
| `Q` | ใช้ Med Kit 1 ชิ้น ฟื้น 25% ของ HP สูงสุด |
| `Enter` / คลิก | เลือกเมนูและอ่านข้อความต่อ |

บนมือถือใช้ D-pad ซ้ายเพื่อเคลื่อนที่, ลากวงเล็งขวาเพื่อเล็ง/ยิง, ปุ่ม `INTERACT` ที่ปรากฏตามบริบท และปุ่ม `MED KIT`

## วงจรเกม

สำรวจ Landing Zone, Crystal Field และ Abandoned Signal Base เพื่อเก็บ Scrap Metal, Energy Crystal และ Circuit Part จากนั้นกลับมาซ่อม Power, Navigation และ Engine ผ่าน mini-game ของแต่ละระบบ เมื่อซ่อมครบจะเริ่ม Final Defense; เอาตัวรอดจน Launch Preparation เสร็จแล้วกด `E` ที่ยานเพื่อจบภารกิจ

## แผนที่

- Landing Zone
- Crystal Field
- Abandoned Signal Base

ขอบเขตที่เดินผ่านได้และไม่ได้แก้ไขได้จาก `CollisionPolygon2D` ภายใต้ `ManualCollision` ในแต่ละฉากของโฟลเดอร์ `Scenes/Levels` โดยใช้เครื่องมือวาด Polygon ใน Godot Editor

## ระบบเกิดใหม่ของศัตรู

ศัตรูทั่วไปใน Crystal Field และ Abandoned Signal Base ใช้ spawn slots และเริ่มนับถอยหลัง 60 วินาทีเมื่อถูกกำจัด ระบบจะไม่สร้างเกินจำนวนสูงสุดของพื้นที่ และจะเลื่อนการเกิดหากผู้เล่นอยู่ใกล้หรือจุดเกิดอยู่ในกล้อง เมื่อออกแล้วกลับเข้าฉาก ศัตรูทั่วไปจะกลับมาพร้อม HP/AI เริ่มต้น แต่ไอเทมเนื้อเรื่อง ระบบยาน และความคืบหน้าถาวรยังคงเดิม

สำหรับฉาก Hive ใช้ `Scenes/Gameplay/hive_respawn_group.tscn` ซึ่งตั้งไว้ 30 วินาที สูงสุด 10 ตัว และรองรับ `alien_egg.tscn` ส่วนบอสหรือศัตรูเนื้อเรื่องต้องวางไว้นอก EnemyRespawnManager เพื่อไม่ให้เกิดใหม่จากระบบสำรวจ

## เปิดโปรเจกต์

1. เปิดโฟลเดอร์โปรเจกต์ด้วย Godot 4.7 หรือใหม่กว่า
2. กด `F5` เพื่อเริ่มเกมจากฉากหลัก

## อัปเดตเกมบนเว็บ

หลังแก้เกม ให้ Export preset **Web** ไปที่ `docs/index.html` แล้ว commit ไฟล์ที่เปลี่ยนใน `docs/` ขึ้น GitHub มิฉะนั้นหน้าเว็บจะยังเปิดเกมจาก Web export เวอร์ชันเดิม

ตัวอย่างคำสั่ง:

```powershell
Godot_v4.7-stable_win64.exe --headless --path . --export-release Web docs/index.html
```

## Extended progression systems

The current campaign flow is Landing Zone → Crystal Field → Abandoned Signal Base → Alien Hive → Boss Arena → return to the ship. Repairing Power, Navigation, and Engine no longer unlocks launch by itself. The player must contact the UNKNOWN AI, enter the Hive, defeat the Hive Matriarch, recover its guaranteed Final Launch Core, and install that core at the ship console before launch becomes available.

- Crawlers, Spitters, and Stalkers use reusable `EnemyDropTable` resources. Their renewable combat materials are Alien Biomass, Hardened Carapace, Acid Gland, and Alien Core; they never replace fixed ship-repair pickups.
- The ship console provides Ship Repair, Weapon Upgrade, Ship Status, and ECHO sections. Damage, Fire Rate, and Energy each have three one-time levels with real inventory costs.
- Press `Space` (or use the on-screen DODGE button) for a short cooldown-limited evasive burst with brief invulnerability.
- Crystal Field and Signal Base use 60-second slot respawns. The Hive uses a 30-second interval, a maximum-alive cap, proximity/camera protection, renewable eggs, and stronger Stalkers.
- The Boss Arena has no exploration respawn manager. The Matriarch uses three health phases, intentional summons, readable attacks, permanent defeat state, and a 100% Final Launch Core drop.
- Inventory, repair state, story discoveries, upgrades, boss defeat, final-core possession, and final installation are saved. Normal exploration enemies reset on scene re-entry, while fixed world pickups remain collected.

Run `Tests/extended_progression_test.tscn` headlessly to verify drop configuration, upgrade transactions and real weapon stats, Hive/Boss gating, boss phases/damage, the guaranteed final core, installation, launch gating, and save payload persistence.

## Credits

โปรเจกต์ตั้งต้นสำหรับรายวิชา Computer Game Development, College of Computing, Khon Kaen University และได้รับการพัฒนาต่อเป็น OLETHROS // ZONE-67
