const request = require('supertest');
const express = require('express');

// Minimal express app for health check test (no DB needed)
const app = express();
app.get('/health', (req, res) => res.json({ status: 'ok' }));

describe('Health check', () => {
  it('GET /health returns 200 and status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
