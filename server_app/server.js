const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
dns.setServers(['8.8.8.8', '1.1.1.1']);

require('dotenv').config();
const express   = require('express');
const cors      = require('cors');
const helmet    = require('helmet');
const morgan    = require('morgan');
const rateLimit = require('express-rate-limit');
const { connectDB } = require('./config/db');

const app = express();
const isProd = process.env.NODE_ENV === 'production';

if (isProd) {
  app.set('trust proxy', 1);
}

// ── Handle unhandled rejections (#23) ─────────────────────────────────────────
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason);
  process.exit(1);
});
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  process.exit(1);
});

// Connect to MongoDB
connectDB();

// Security middleware
app.use(helmet());

// CORS (#8) — ALLOWED_ORIGIN must be set in production .env
const allowedOrigin = process.env.ALLOWED_ORIGIN;
if (isProd && !allowedOrigin) {
  console.warn('WARNING: ALLOWED_ORIGIN is not set. CORS will block all cross-origin requests in production.');
}
app.use(cors({
  origin: isProd ? (allowedOrigin || false) : '*',
  credentials: true,
}));

// Rate limiting
app.use(rateLimit({
  windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max:      Number(process.env.RATE_LIMIT_MAX) || 100,
  message:  { error: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
}));

// Body parser
app.use(express.json({ limit: '10kb' }));

// Logging (#24) — 'dev' in development, 'combined' in production
app.use(morgan(isProd ? 'combined' : 'dev'));

// Health check
app.get('/health', async (req, res) => {
  let dbStatus = 'disconnected';
  try {
    const { getDb } = require('./config/db');
    const db = getDb();
    // Dry-run query to Firestore to verify connectivity
    await db.collection('health_checks').limit(1).get();
    dbStatus = 'connected';
  } catch (err) {
    dbStatus = 'error: ' + err.message;
  }

  const firebaseConfigured = !!(process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY);

  const isHealthy = dbStatus === 'connected';

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'healthy' : 'unhealthy',
    time: new Date().toISOString(),
    services: {
      database: {
        status: dbStatus,
        type: 'Firestore'
      },
      phone_otp: {
        status: firebaseConfigured ? 'configured' : 'missing_config',
        provider: 'Firebase Auth'
      }
    },
    environment: process.env.NODE_ENV || 'development'
  });
});

// Welcome route
app.get('/', (req, res) => res.json({
  message: 'Welcome to UPI Tracker API',
  status: 'running',
  healthCheck: '/health',
}));

// Routes
app.use('/api/auth',     require('./routes/auth'));
app.use('/api/expenses', require('./routes/expenses'));

// 404 handler
app.use((req, res) => res.status(404).json({ error: 'Route not found.' }));

// Global error handler (#29) — hide stack traces in production
app.use((err, req, res, next) => {
  console.error(err.stack);
  const status  = err.status || 500;
  const message = (isProd && status === 500) ? 'Internal server error.' : (err.message || 'Internal server error.');
  res.status(status).json({ error: message });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT} [${process.env.NODE_ENV}]`));
