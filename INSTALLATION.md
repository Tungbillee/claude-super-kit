# 🚀 Installation Guide - Claude Super Kit

Hướng dẫn cài đặt Claude Super Kit vào hệ thống Claude Code của anh.

---

## 📋 Yêu cầu

- **macOS** hoặc **Linux** (Windows xem phần riêng bên dưới)
- **Claude Code** đã cài sẵn (CLI hoặc VSCode extension)
- **Git** đã cài
- **bash** (mặc định có trên macOS/Linux)
- Quyền ghi vào `~/.claude/`

---

## 🎯 Cách 1: Cài từ GitHub (Recommended)

### Bước 1: Clone repo

```bash
# Clone Super Kit về máy
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/Tungbillee/claude-super-kit.git
cd claude-super-kit
```

### Bước 2: Backup Claude Code hiện tại (nếu có)

```bash
# Backup an toàn trước khi install
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M)"
mkdir -p "$BACKUP_DIR"
[ -d ~/.claude/skills ] && cp -r ~/.claude/skills "$BACKUP_DIR/skills"
[ -d ~/.claude/commands ] && cp -r ~/.claude/commands "$BACKUP_DIR/commands"
[ -d ~/.claude/rules ] && cp -r ~/.claude/rules "$BACKUP_DIR/rules"
echo "Backup at: $BACKUP_DIR"
```

### Bước 3: Chạy installer

```bash
chmod +x install.sh
./install.sh
```

**Output mong đợi:**
```
==========================================
  Claude Super Kit Installer v2.0
==========================================

Super Kit dir: /Users/your-name/projects/claude-super-kit
Target dir:    /Users/your-name/.claude

[1/3] Linking ALL skills...
  ✓ Linked 120 skills (replaced 0 existing)
[2/3] Linking ALL commands...
  ✓ Linked 27 command items
[3/3] Linking ALL rules...
  ✓ Linked 7 rules

==========================================
  Installation complete!
==========================================
```

### Bước 4: Verify

```bash
# Đếm skills đã link
ls ~/.claude/skills/ | wc -l
# Output: 120

# Check 1 skill cụ thể
cat ~/.claude/skills/sk-plan/SKILL.md | head -10
```

### Bước 5: Test trong Claude Code

Mở Claude Code session **mới** (close + open lại để load skills mới), gõ:

```
/sk:plan "Build a login feature"
```

→ Mong đợi: dropdown gợi ý `/sk:plan`, AskUserQuestion popup hiện ra.

---

## 🎯 Cách 2: Cài qua curl (Quick install)

```bash
# One-liner install
curl -fsSL https://raw.githubusercontent.com/Tungbillee/claude-super-kit/main/install.sh | bash
```

⚠️ **Lưu ý:** Cách này clone vào `~/projects/claude-super-kit/` mặc định.

---

## 🪟 Windows Installation

### Yêu cầu
- **Git for Windows** (cài Git Bash)
- **WSL2** (Recommended) hoặc Git Bash

### Cách cài (qua Git Bash)

```bash
# Trong Git Bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/Tungbillee/claude-super-kit.git
cd claude-super-kit
chmod +x install.sh
./install.sh
```

⚠️ **Note Windows:**
- `~/.claude/` thường ở `C:\Users\<username>\.claude\`
- Symlinks cần admin rights hoặc Developer Mode enabled
- Nếu symlink fail, dùng cách "Copy mode" bên dưới

### Copy mode cho Windows (nếu symlink fail)

```bash
# Copy thay vì symlink
cp -r skills/* ~/.claude/skills/
cp -r commands/* ~/.claude/commands/
cp rules/interactive-ui-protocol.md ~/.claude/rules/
cp rules/language-response.md ~/.claude/rules/
```

⚠️ Trade-off: Update Super Kit phải copy lại thủ công.

---

## 🔄 Update Super Kit

### Pull updates mới

```bash
cd ~/projects/claude-super-kit
git pull origin main
```

→ Vì dùng symlink nên updates **tự động** áp dụng vào `~/.claude/`. Không cần chạy lại install.

### Chạy lại install nếu có thay đổi cấu trúc

```bash
cd ~/projects/claude-super-kit
./install.sh
```

---

## 🗑️ Uninstall

### Cách 1: Xóa symlinks (giữ Super Kit local)

```bash
# Xóa các symlinks sk-* trong ~/.claude/
find ~/.claude/skills -maxdepth 1 -name "sk-*" -type l -delete
find ~/.claude/skills -maxdepth 1 -type l ! -name "sk-*" -delete

# Xóa rules đã thêm
rm -f ~/.claude/rules/interactive-ui-protocol.md
rm -f ~/.claude/rules/language-response.md

# Xóa commands sk-*
find ~/.claude/commands -maxdepth 1 -name "sk*" -type l -delete
```

### Cách 2: Restore backup (về ClaudeKit gốc)

```bash
# Tìm backup gần nhất
LATEST_BACKUP=$(ls -td ~/.claude-backup-* 2>/dev/null | head -1)
echo "Backup found: $LATEST_BACKUP"

# Restore
rm -rf ~/.claude/{skills,commands,rules}
cp -r "$LATEST_BACKUP"/{skills,commands,rules} ~/.claude/
echo "Restored from $LATEST_BACKUP"
```

### Cách 3: Xóa hoàn toàn

```bash
# Xóa cả backup + Super Kit + symlinks
rm -rf ~/projects/claude-super-kit
rm -rf ~/.claude-backup-*
rm -rf ~/.claude/skills ~/.claude/commands ~/.claude/rules
mkdir -p ~/.claude/{skills,commands,rules}
```

⚠️ **WARNING:** Cách 3 xóa SẠCH. Backup trước nếu cần.

---

## 🐛 Troubleshooting

### Issue 1: `/sk:*` commands không hiện trong Claude Code

**Nguyên nhân:** Claude Code chưa reload skills.

**Fix:**
1. Close Claude Code session hoàn toàn
2. Mở session mới
3. Gõ `/` để xem dropdown
4. Tìm `sk:*` commands

### Issue 2: Symlinks tồn tại nhưng skill không load

**Check:**
```bash
ls -la ~/.claude/skills/sk-plan
# Mong đợi: lrwxr-xr-x ... sk-plan -> /Users/.../claude-super-kit/skills/sk-plan/

# Verify symlink target tồn tại
readlink -f ~/.claude/skills/sk-plan
ls $(readlink -f ~/.claude/skills/sk-plan)/SKILL.md
```

**Fix:** Nếu broken symlink, chạy lại `./install.sh`.

### Issue 3: Permission denied khi chạy install.sh

**Fix:**
```bash
chmod +x install.sh
chmod +x scripts/*.sh
./install.sh
```

### Issue 4: ClaudeKit gốc bị mất sau install

**Don't worry!** Backup tự động tại `~/.claude-backup-*`. Restore:
```bash
LATEST_BACKUP=$(ls -td ~/.claude-backup-* 2>/dev/null | head -1)
cp -r "$LATEST_BACKUP"/skills/* ~/.claude/skills/
```

### Issue 5: `/sk:debug-fix` không respond

**Check skill có exist:**
```bash
cat ~/.claude/skills/sk-debug-fix/SKILL.md | head -5
# Mong đợi: name: sk:debug-fix
```

**Nếu thiếu:** chạy lại `./install.sh`.

### Issue 6: Validator báo lỗi

```bash
cd ~/projects/claude-super-kit
bash scripts/validate-skills.sh
```

→ Nếu có error, copy paste output gửi qua GitHub Issue.

---

## 📂 Cấu trúc cài đặt

Sau khi install thành công:

```
~/.claude/
├── skills/                       (120 symlinks)
│   ├── sk-plan -> ~/projects/claude-super-kit/skills/sk-plan/
│   ├── sk-cook -> ...
│   ├── sk-debug-fix -> ...
│   └── ... (117 skills khác)
├── commands/
│   ├── sk-help.md (symlink)
│   ├── plan.md, cook.md, fix.md (symlinks)
│   └── ...
└── rules/
    ├── interactive-ui-protocol.md
    ├── language-response.md
    └── ...

~/projects/claude-super-kit/      (Source repo)
├── README.md
├── INSTALLATION.md (this file)
├── LICENSE, CONTRIBUTING.md, CHANGELOG.md, DEPRECATIONS.md
├── CLAUDE.md
├── install.sh
├── skills/ (120 skills)
├── commands/ (27 items)
├── rules/ (7 rules)
├── scripts/ (rename, validate, install scripts)
└── .github/workflows/ (CI/CD)

~/.claude-backup-YYYYMMDD-HHMM/   (ClaudeKit gốc backup)
├── skills/
├── commands/
└── rules/
```

---

## ✅ Verify Installation

Run quick verification:

```bash
# 1. Check skills count
echo "Skills: $(ls ~/.claude/skills/ | wc -l) (expected: 120)"

# 2. Check key skills exist
for s in sk-plan sk-cook sk-debug-fix sk-vue-development sk-electron-apps; do
  [ -L ~/.claude/skills/$s ] && echo "✓ $s" || echo "✗ $s MISSING"
done

# 3. Check rules
ls ~/.claude/rules/

# 4. Validator
cd ~/projects/claude-super-kit
bash scripts/validate-skills.sh
```

**Expected output:**
```
Skills: 120 (expected: 120)
✓ sk-plan
✓ sk-cook
✓ sk-debug-fix
✓ sk-vue-development
✓ sk-electron-apps

interactive-ui-protocol.md
language-response.md
... (more rules)

Skills checked: 117
Total issues: 0
✓ All skills pass validation
```

---

## 🎯 Test các skills chính

Mở Claude Code session mới, thử các commands:

```
/sk:plan "Build authentication"      # Plan với LLM Assignment
/sk:debug-fix "Bug in login"          # Unified debug + fix (NEW)
/sk:vue-development                   # Vue 3
/sk:nuxt-full-stack                   # Nuxt 3
/sk:electron-apps                     # Electron
/sk:payment-vnpay                     # VNPay
/sk:payment-momo                      # MoMo
/sk:brainstorm                        # với LLM recommendation
/sk:help                              # menu skills
```

---

## 🔗 Resources

- **GitHub:** https://github.com/Tungbillee/claude-super-kit
- **Issues:** https://github.com/Tungbillee/claude-super-kit/issues
- **Email:** sanpema1998@gmail.com

---

## 🆘 Cần help?

1. Check **Troubleshooting** section ở trên
2. Run validator: `bash scripts/validate-skills.sh`
3. Mở GitHub Issue với:
   - OS version (macOS/Linux/Windows)
   - Output của `bash install.sh`
   - Output của `ls -la ~/.claude/skills/sk-plan` (1 skill mẫu)

---

**Last updated:** 2026-04-25
**Version:** v1.1.0
