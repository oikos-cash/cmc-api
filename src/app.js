import express from 'express';
import dotenv from 'dotenv';

import router from './routes/index.js';

dotenv.config();

const app = express();

app.use(router);

app.listen(8088, () => {
  console.log('Server running');
});
