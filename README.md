# Smart Expense Intelligence

![Tech Stack](https://img.shields.io/badge/Flutter-Dart-blue)
![Database](https://img.shields.io/badge/Database-SQLite-lightgrey)
![Machine Learning](https://img.shields.io/badge/ML-Google_ML_Kit-orange)

**Smart Expense Intelligence** is an offline-first, privacy-centric personal finance application. It completely automates the expense tracking process by utilizing on-device Machine Learning (OCR) for receipt scanning and background SMS parsing for bank transaction extraction, ensuring user financial data never leaves the device.

---

## 📸 Interface Preview
<img width="229" height="484" alt="image" src="https://github.com/user-attachments/assets/2b15e24d-26d9-46eb-9abc-56f7dae605e1" />
<img width="231" height="484" alt="image" src="https://github.com/user-attachments/assets/e4e7bba3-3aa2-40f6-a58e-43aff0e0747d" />
<img width="228" height="484" alt="image" src="https://github.com/user-attachments/assets/9a301327-b839-44b7-b723-cc0e87cbcc8b" />
<img width="225" height="484" alt="image" src="https://github.com/user-attachments/assets/e248346a-2869-4835-a596-e24875a67e55" />




## 🚀 Key Features
* **On-Device Machine Learning:** Integrates Google ML Kit's OCR engine to instantly scan, parse, and categorize paper receipts without requiring cloud processing.
* **Automated SMS Parsing:** Silently reads incoming bank transaction SMS messages in the background to automatically log expenses in real-time.
* **Privacy-by-Design Architecture:** Operates entirely offline using local data persistence, ensuring sensitive financial telemetry remains strictly on the user's hardware.
* **Intelligent Dashboard:** Visualizes spending habits and transaction histories through a custom Flutter UI.

## 🛠️ Technical Stack
* **Frontend Framework:** Flutter, Dart
* **Local Database:** SQLite
* **Machine Learning & APIs:** Google ML Kit (Optical Character Recognition)
* **Architecture:** Offline-First, Background Processing, Privacy-Centric Design

---

## 💻 Local Development Setup

**1. Clone the repository:**
`git clone https://github.com/theekshana-git/Smart-Expense-Intelligence-App.git`  
`cd Smart-Expense-Intelligence-App`

**2. Install dependencies:**
`flutter pub get`

**3. Run the application:**
`flutter run`
*(Note: To test the background SMS parsing and OCR receipt scanning, it is highly recommended to run this on a physical device rather than a web emulator).*
