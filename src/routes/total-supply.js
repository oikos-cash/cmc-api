import dotenv from 'dotenv';
dotenv.config();

import cache from 'memory-cache';
import { ethers, Contract, JsonRpcProvider } from "ethers";
import ERC20 from '../assets/ERC20.json' assert { type: 'json' };

const provider = new JsonRpcProvider(process.env.RPC_URL);

const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS;
const CACHE_LIMIT = 5 * 1000 * 60; // 5 minutes
const CACHE_KEY = 'totalSupply';


const getTotalSupply = async (req, res) => {
  if (cache.get(CACHE_KEY)) {
    return res.send((cache.get(CACHE_KEY)).toString());
  }

  try {
    // Check if contract exists
    const code = await provider.getCode(TOKEN_ADDRESS);
    if (code === "0x") {
      console.error(`No contract deployed at address: ${TOKEN_ADDRESS}`);
      return res.status(400).json({ error: "Invalid TOKEN_ADDRESS — no contract deployed" });
    }

    // Instantiate contracts
    const tokenContract = new Contract(TOKEN_ADDRESS, ERC20.abi, provider);

    // Fetch data
    const totalSupply = await tokenContract.totalSupply();

    console.log(`Total Supply: ${ethers.formatUnits(totalSupply, 18)}`);

    // Cache and return result
    cache.put(CACHE_KEY, Number(ethers.formatUnits(totalSupply, 18)), CACHE_LIMIT);
    return res.send(cache.get(CACHE_KEY).toString());

  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
};

export default getTotalSupply;
