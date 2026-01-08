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

> 🌐 **Simple DNS Management Tool for Windows** - Change DNS with one click!

A lightweight, portable DNS management tool similar to DNS Jumper. No installation required - just run and use!

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔄 **Quick DNS Change** | Switch DNS with one click from preset providers |
| 🌍 **IPv4 + IPv6 Support** | Modern dual-stack DNS configuration |
| 📊 **DNS Benchmark** | Test and compare ping times for all DNS providers |
| 🚀 **Speed Test** | Built-in internet speed test |
| 🧹 **Flush DNS Cache** | Clear DNS cache instantly |
| 🌐 **Multi-language** | English and Vietnamese (Tieng Viet) |
| 📦 **Portable** | Single file, no installation needed |

## 📥 Installation

### Option 1: One-liner (PowerShell) - Recommended ⚡
Open PowerShell **as Administrator** and run:
```powershell
irm https://anhhackta.github.io/DNS-JoinV/DNS-JoinV.cmd | iex
```

Or download and run:
```powershell
irm https://anhhackta.github.io/DNS-JoinV/DNS-JoinV.cmd -OutFile DNS-JoinV.cmd; .\DNS-JoinV.cmd
```

### Option 2: Download and Run
1. Download `DNS-JoinV.cmd` from [Releases](https://github.com/anhhackta/DNS-JoinV/releases)
2. Double-click to run
3. Click "Yes" when prompted for Administrator privileges

## 🎯 Supported DNS Providers

| Provider | IPv4 Primary | IPv4 Secondary | IPv6 |
|----------|--------------|----------------|------|
| **Google DNS** | 8.8.8.8 | 8.8.4.4 | ✅ |
| **Cloudflare** | 1.1.1.1 | 1.0.0.1 | ✅ |
| **OpenDNS** | 208.67.222.222 | 208.67.220.220 | ✅ |
| **AdGuard DNS** | 94.140.14.14 | 94.140.15.15 | ✅ |
| **Quad9** | 9.9.9.9 | 149.112.112.112 | ✅ |
| **Quad9 No Security** | 9.9.9.10 | 149.112.112.10 | ✅ |
| **Verisign** | 64.6.64.6 | 64.6.65.6 | ✅ |
| **Orange DNS** | 195.92.195.94 | 195.92.195.95 | ❌ |
| **Norton DNS** | 198.153.192.1 | 198.153.194.1 | ❌ |
| **Next DNS** | 45.90.28.217 | 45.90.30.217 | ❌ |
| **Control D** | 76.76.2.2 | 76.76.10.2 | ✅ |

## 📖 Usage

### Change DNS
1. Select your **Network Adapter** from dropdown
2. Choose a **DNS Provider** 
3. Check/uncheck **"Also set IPv6 DNS"** option
4. Click **"Apply DNS"**

### Reset to Default
Click **"Reset to DHCP"** to restore automatic DNS from your ISP.

### Find Fastest DNS
Click **"Benchmark All"** to test ping times for all DNS providers and find the fastest one for your location.

## 🔧 Requirements

- Windows 10/11
- PowerShell 5.1 or later (pre-installed on Windows 10+)
- Administrator privileges (for changing DNS settings)

## 🌐 Languages

- **English** (Default)
- **Tiếng Việt** (Vietnamese - no diacritics: Tieng Viet)

Switch language using the dropdown at the top-right corner.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**@anhhackta**

- GitHub: [@anhhackta](https://github.com/anhhackta)

## 🤝 Contributing

Contributions, issues and feature requests are welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## ⭐ Show your support

Give a ⭐ if this project helped you!

---

<p align="center">Made with ❤️ by <a href="https://github.com/anhhackta">@anhhackta</a></p>
