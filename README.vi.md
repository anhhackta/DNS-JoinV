# DNS JoinV

<p align="center">
  <a href="https://www.microsoft.com/windows">
    <img src="https://img.shields.io/badge/Platform-Windows-blue?style=for-the-badge&logo=windows" alt="Platform">
  </a>
  <a href="https://learn.microsoft.com/en-us/powershell/">
    <img src="https://img.shields.io/badge/PowerShell-5.1+-blue?style=for-the-badge&logo=powershell" alt="PowerShell">
  </a>
  <a href="https://github.com/anhhackta/DNS-JoinV?tab=MIT-1-ov-file#">
    <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
  </a>
</p>

> 🌐 **DNS JoinV — Công cụ quản lý DNS nhỏ gọn cho Windows**

Một công cụ di động, nhẹ để thay đổi DNS nhanh chóng (tương tự DNS Jumper). Không cần cài đặt — chạy trực tiếp file `DNS-JoinV.cmd`.

## ✨ Tính năng

- 🔄 Thay đổi DNS nhanh chỉ với một click
- 🌍 Hỗ trợ IPv4 và IPv6
- 📊 Benchmark DNS để so sánh độ trễ (DNS latency) hoặc ICMP ping
- 🚀 Test tốc độ Internet (download / upload)
- 🧹 Xóa cache DNS (Flush DNS)
- 🌐 Hỗ trợ đa ngôn ngữ: Tiếng Anh và Tiếng Việt
- 📦 Portable — 1 file, không cần cài đặt

## 📥 Cài đặt

### Cách 1: Một lệnh (PowerShell) — Khuyến nghị ⚡
Mở PowerShell bằng quyền Administrator và chạy:

```powershell
irm https://anhhackta.github.io/DNS-JoinV/install.ps1 | iex
```

Hoặc tải về và chạy:

```powershell
irm https://anhhackta.github.io/DNS-JoinV/DNS-JoinV.cmd -OutFile DNS-JoinV.cmd; .\DNS-JoinV.cmd
```

### Cách 2: Tải về và chạy
1. Tải `DNS-JoinV.cmd` từ trang Releases
2. Nhấp đúp để chạy
3. Chọn "Yes" khi được yêu cầu quyền Administrator

## 🎯 Nhà cung cấp DNS hỗ trợ

| Nhà cung cấp | IPv4 chính | IPv4 phụ | IPv6 |
|-------------|------------:|---------:|-----:|
| Google DNS  | 8.8.8.8     | 8.8.4.4  | ✅   |
| Cloudflare  | 1.1.1.1     | 1.0.0.1  | ✅   |
| OpenDNS     | 208.67.222.222 | 208.67.220.220 | ✅ |
| AdGuard DNS | 94.140.14.14 | 94.140.15.15 | ✅ |
| Quad9       | 9.9.9.9     | 149.112.112.112 | ✅ |
| Quad9 NoSec | 9.9.9.10    | 149.112.112.10 | ✅ |
| Verisign    | 64.6.64.6   | 64.6.65.6 | ✅ |
| Control D   | 76.76.2.2   | 76.76.10.2 | ✅ |
| NextDNS     | 45.90.28.217 | 45.90.30.217 | ❌ |

> Ghi chú: bảng dựa trên cấu hình trong mã nguồn; một số dịch vụ có/không hỗ trợ IPv6.

## 📖 Hướng dẫn sử dụng

### Đổi DNS
1. Chọn `Network Adapter` (card mạng) từ dropdown
2. Chọn `DNS Provider` từ danh sách
3. Tích / bỏ tích `IPv6` nếu muốn đồng thời cấu hình IPv6
4. Nhấn `Apply DNS`

### Reset về DHCP
Nhấn `Reset to DHCP` để lấy cấu hình tự động từ nhà cung cấp mạng (ISP).

### Tìm DNS nhanh nhất
Nhấn `Benchmark All` để đo và so sánh độ trễ (có thể chọn đo `DNS Latency` hoặc `ICMP Ping`).

### Test tốc độ mạng
Nhấn `Speed Test` để đo download/upload; công cụ sẽ tải/đẩy dữ liệu mẫu và hiển thị kết quả (Mbps và MB/s).

### Xóa cache DNS
Nhấn `Flush DNS` để xóa cache DNS trên hệ thống.

## 🔧 Yêu cầu

- Windows 10/11
- PowerShell 5.1 hoặc mới hơn
- Quyền Administrator (khi thay đổi cấu hình mạng)

## 🌐 Ngôn ngữ

- **English** (mặc định)
- **Tiếng Việt**

Chuyển ngôn ngữ bằng dropdown ở góc trên phải.

## 📝 License

Bản quyền theo giấy phép MIT — xem file `LICENSE` để biết chi tiết.

## 👤 Tác giả

**@anhhackta** — GitHub: https://github.com/anhhackta

---

Made with ❤️ by @anhhackta
