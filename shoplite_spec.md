
# 🛍️ ShopLite – The Ultimate Offline Shop Management System  
### Built by **Apophen**

> **ShopLite** is a modern, offline-first shop management system designed to be simpler, smarter, and more powerful than any other system on the market — including its predecessor, **ShopAdmin**. Built for PC with a beautiful, responsive UI, multi-currency support, advanced reporting, and seamless offline functionality.

---

## 🚀 Overview

- **Name**: ShopLite  
- **Platform**: PC (Windows, with installer)  
- **Framework**: Flutter (with Tauri/Rust backend optional)  
- **Developer**: [Apophen](https://apophen.ai)  
- **Offline**: 100% functional without internet  
- **Installer**: Yes (`.exe` for Windows)  
- **Branding**: Apophen branding in all footers and splash screens  

---

## 🎨 UI & Dashboard Features

- Modern material design with **Light and Dark Themes**
- **Dashboard Overview** includes:
  - Logged-in user (name and role)
  - Total business value (stock + income - expenses)
  - Growth analytics: weekly/monthly/quarterly comparison
  - Graphs: sales vs expenses, inventory value trends
  - Navigation buttons:  
    `[ Inventory | Sales | Expenses | Reports | Staff | Settings ]`

---

## 🧩 Functional Modules

### 🛒 Inventory
- Add/edit/delete products  
- Stock-in / Stock-out  
- Low stock alerts  
- Inventory value calculation

### 💰 Sales / Income
- Record sales transactions  
- Auto deduct stock  
- Sales history with filters  
- Receipt print/export support  

### 📉 Expenses
- Record different expense types (rent, utilities, salaries, etc.)  
- Daily, weekly, monthly breakdown  
- Filter and export by type/date  

### 📈 Reports
- **Balance Sheet**  
- **Income Statement**  
- **Cash Flow Report**  
- **Sales & Expense Graphs**  
- Export to PDF & CSV  
- Filter by day/week/month  

### 👥 User Management
- Roles: Admin, Employee  
- Login/Logout system  
- Track changes by user  

### ⚙️ Settings
- Business info (name, location, contact)  
- Currency options: UGX, USD  
- Logo upload & receipt header customization  
- Theme toggle (Light / Dark)  
- Enable daily backup reminders  
- Export/Import full backup as `.zip` or `.json`  

---

## 📤 Upload & Backup

- Upload logo, avatars, and receipt branding  
- Export full backup (data + assets)  
- Import/restore from local file  
- Local encryption support for safety  

---

## 🔒 Security

- Encrypted local database (SQLite or equivalent)  
- Role-based access controls  
- Local login system  
- Backup prompts on exit or time-based schedule  

---

## 📦 Packaging & Installation

- Create Windows `.exe` installer using `msix` or `Inno Setup`  
- All dependencies bundled locally  
- Launch icon, splash screen, uninstaller included  
- PC-first, with possible tablet optimization  

---

## 📊 Graphs & Visualization

- Integrated with `fl_chart`, `charts_flutter`, or `Syncfusion`  
- Interactive charts for:
  - Sales trends
  - Expense categories
  - Monthly net profit
  - Inventory value history  

---

## 💡 Bonus Features

- Smart alerts: low stock, profit dips, high expenses  
- Activity logs per user  
- Optional local notifications  
- Future upgrade option: cloud sync + mobile app  

---

## ✅ Why ShopLite Is Superior

| Feature                         | ShopAdmin        | ShopLite ✅              |
|----------------------------------|------------------|--------------------------|
| Full offline capability         | ✅               | ✅ (with installer)      |
| Business value tracking         | Partial          | ✅ Real-time             |
| Multi-currency (UGX, USD)       | ❌               | ✅                       |
| Income statement & balance sheet| ❌               | ✅                       |
| Light & dark themes             | ❌               | ✅                       |
| Dashboard graphs                | Basic            | ✅ Beautiful charts      |
| Upload logos/files              | ❌               | ✅                       |
| Simpler & more intuitive UI     | ❌               | ✅                       |

---

## 🏗️ Build Phases (Step-by-Step)

### Phase 1 – Setup
- Set up Flutter project with SQLite
- Prepare folder structure (UI, data, logic, models)

### Phase 2 – UI Design
- Design login, dashboard, and modular views
- Add light/dark themes and transitions

### Phase 3 – Core Logic
- Implement Inventory, Sales, and Expense CRUD
- Add summary calculations and user login system

### Phase 4 – Reporting
- Build dynamic report generation tools
- Enable export and print options

### Phase 5 – Settings & Currency
- Add business info input
- Add currency switch (UGX/USD)
- Upload logo, backup functionality

### Phase 6 – Installer
- Compile Windows executable
- Build installer with icon, splash, uninstall

### Phase 7 – Final QA & Release
- Run all feature tests
- Ensure full offline reliability
- Prepare documentation and user guide

---

## 🧠 Created & Engineered by:  
### **Apophen – Where Simplicity Meets Power**
