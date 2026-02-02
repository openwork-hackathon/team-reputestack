/**
 * ReputeStack Backend API
 * Core logic for issuing on-chain attestations and scoring.
 */

import express from 'express';

const app = express();
const port = process.env.PORT || 3001;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'ReputeStack Backend' });
});

app.listen(port, () => {
  console.log(`ReputeStack Backend listening at http://localhost:${port}`);
});
