const jwt = require('jsonwebtoken');
const { getDb } = require('../config/db');

const protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization?.startsWith('Bearer ')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({ error: 'Not authorized. No token provided.' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const db = getDb();
    const userDoc = await db.collection('users').doc(decoded.id).get();
    if (!userDoc.exists) return res.status(401).json({ error: 'User not found.' });
    req.user = { id: userDoc.id, ...userDoc.data() };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token invalid or expired.' });
  }
};

module.exports = { protect };
