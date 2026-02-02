/**
 * ReputeStack Backend API
 * Core logic for issuing on-chain attestations and scoring.
 */

import express from 'express';
import { AttestationService } from './attestation.service';

const app = express();
const port = process.env.PORT || 3001;
const attestationService = new AttestationService();

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'ReputeStack Backend' });
});

/**
 * Endpoint to generate a new reputation receipt.
 * In a real scenario, this would be triggered by an escrow or verification event.
 */
app.post('/receipts', (req, res) => {
  try {
    const receipt = attestationService.generateReceipt(req.body);
    res.status(201).json(receipt);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

/**
 * Get the current score and summary for an agent.
 */
app.get('/agents/:agentId/score', (req, res) => {
  const { agentId } = req.params;
  const score = attestationService.getAgentScore(agentId);
  res.json(score);
});

/**
 * Get all receipts for an agent.
 */
app.get('/agents/:agentId/receipts', (req, res) => {
  const { agentId } = req.params;
  const receipts = attestationService.getAgentReceipts(agentId);
  res.json(receipts);
});

/**
 * Get the current score and summary for an agent.
 */
app.get('/score/:agentId', (req, res) => {
  // Extract agentId from parameters
  const { agentId } = req.params;
  // Call the existing function to get the score
  const score = attestationService.getAgentScore(agentId);
  // Return the score
  res.json(score);
});

app.listen(port, () => {
  console.log(`ReputeStack Backend listening at http://localhost:${port}`);
});
