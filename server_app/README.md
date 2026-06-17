# UPI Tracker API

Node.js + Express + MongoDB backend for the UPI Expense Tracker Flutter app.

---

## Quick start

```bash
# 1. Install dependencies
npm install

# 2. Copy and fill in environment variables
cp .env.example .env

# 3. Start development server
npm run dev

# 4. Start production server
npm start
```

---

## Project structure

```
upi-tracker-api/
├── config/
│   └── db.js                 # MongoDB connection
├── controllers/
│   ├── authController.js     # Register, login, me
│   └── expenseController.js  # CRUD + summary
├── middleware/
│   └── auth.js               # JWT protect middleware
├── models/
│   ├── User.js               # User schema
│   └── Expense.js            # Expense schema
├── routes/
│   ├── auth.js               # /api/auth/*
│   └── expenses.js           # /api/expenses/*
├── utils/
│   └── categorize.js         # Auto-categorize + parse UPI notifications
├── .env.example
├── .gitignore
├── package.json
└── server.js                 # Entry point
```

---

## API reference

### Auth

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login, get JWT |
| GET  | `/api/auth/me` | Get current user |

**Register body:**
```json
{ "name": "Dhamo", "email": "dhamo@example.com", "password": "secret123", "phone": "9876543210" }
```

**Login response:**
```json
{ "token": "eyJ...", "user": { "id": "...", "name": "Dhamo", "email": "..." } }
```

---

### Expenses  
All routes require `Authorization: Bearer <token>` header.

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST   | `/api/expenses` | Add expense |
| GET    | `/api/expenses` | List expenses (paginated) |
| GET    | `/api/expenses/summary` | Monthly summary + category breakdown |
| PATCH  | `/api/expenses/:id` | Update expense |
| DELETE | `/api/expenses/:id` | Delete expense |

**POST /api/expenses body:**
```json
{
  "amount": 250,
  "payee": "Swiggy",
  "category": "Food & Dining",
  "upiApp": "GPay",
  "upiRef": "TXN123456789",
  "note": "Lunch order",
  "date": "2026-06-16T13:00:00Z"
}
```

**GET /api/expenses query params:**
- `page` (default: 1)
- `limit` (default: 20)
- `month` (1–12)
- `year` (e.g. 2026)
- `category` (e.g. "Food & Dining")

**GET /api/expenses/summary response:**
```json
{
  "month": 6,
  "year": 2026,
  "total": 12450,
  "count": 38,
  "categoryBreakdown": [
    { "_id": "Food & Dining", "total": 4500, "count": 15 },
    { "_id": "Transport",     "total": 2100, "count": 8 }
  ],
  "dailyTrend": [
    { "_id": "2026-06-01", "total": 850, "count": 3 }
  ]
}
```

---

## Deploy to Railway (recommended)

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up

# Set environment variables in Railway dashboard
# Add MONGO_URI, JWT_SECRET, NODE_ENV=production
```

---

## Auto-categorization (utils/categorize.js)

The `parseNotification(text, packageName)` function is used directly from the Flutter app (via the Kotlin notification listener) to:
1. Extract amount, payee, and UPI ref from notification text
2. Auto-detect category based on payee keywords
3. Send structured data to `POST /api/expenses`

---

## MongoDB Atlas setup

1. Go to [cloud.mongodb.com](https://cloud.mongodb.com)
2. Create a free M0 cluster
3. Create a database user
4. Whitelist your server IP (or `0.0.0.0/0` for dev)
5. Copy the connection string into `.env` as `MONGO_URI`
