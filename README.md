🖥️ Hosts - Manage Your Hosts File

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Bash](https://img.shields.io/badge/bash-%3E%3D4.0-orange.svg)

A simple bash script for managing your `/etc/hosts` file with ease.

## ✨ Features

- 🌐 Add new host entries
- ❌ Remove existing host entries
- 📋 List all host entries
- 🔍 Search for host entries
- 📝 Batch add entries from a file
- 🔄 Update script to latest version

## 📦 Installation

```bash
# Direct installation
curl -sSL https://raw.githubusercontent.com/ErvisTusha/hosts/main/hosts.sh | sudo bash -s install

# Or clone and install
git clone https://github.com/ErvisTusha/hosts.git
cd hosts
./hosts.sh install
```

## 🚀 Usage

```bash
# Add a new host entry
hosts.sh add 127.0.0.1 example.com

# Remove a host entry
hosts.sh rm example.com

# List all host entries
hosts.sh list

# Search for a host entry
hosts.sh search example

# Add entries from a file
hosts.sh batch hosts.txt
```

## 🎯 Commands and Options

```
Commands:
  add <ip> <domain>     | Add new host entry
  rm <ip|domain|id>     | Remove host entry
  list                  | List all entries
  search <query>        | Search for host entries
  batch <file>          | Add entries from a file
  install               | Install script to /usr/local/bin
  update                | Update to latest version
  uninstall             | Remove script from system

Options:
  -h, --help            | Show help message
  -v, --version         | Show version information
```

## 🔧 Requirements

- Bash shell
- Root privileges

## 📝 License

Distributed under the MIT License. See `LICENSE` for more information.

## 👤 Author

**Ervis Tusha**

- X: [@ET](https://x.com/ET)
- GitHub: [@ErvisTusha](https://github.com/ErvisTusha)

---

<p align="center">
  Made with ❤️ by <a href="https://www.ervistusha.com">Ervis Tusha</a>
</p>