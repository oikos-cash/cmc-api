import express from 'express';
import cors from 'cors';

import getTotalSupply from './total-supply.js';
import getCirculatingSupply from './circulating-supply.js';

const router = express.Router();

const corsOptions = {
  origin: 'https://accounts.coinmarketcap.com',
};

router.get('/alive', (req, res) => {
  res.send('API is live');
});

router.get('/api/total_supply', cors(corsOptions), getTotalSupply);
router.get('/api/circulating_supply', cors(corsOptions), getCirculatingSupply);
// router.get('/api/pairs/:category', getPairs);
// router.get('/api/ticker/:pair', getTicker);

export default router;
