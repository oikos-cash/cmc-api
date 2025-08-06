import dotenv from 'dotenv';
dotenv.config();

import cache from 'memory-cache';
import { ethers, Contract, JsonRpcProvider } from "ethers";
import BaseVault from '../assets/BaseVault.json' assert { type: 'json' };

const provider = new JsonRpcProvider(process.env.RPC_URL);

const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS;
const CACHE_LIMIT = 5 * 1000 * 60; // 5 minutes
const CACHE_KEY = 'circulatingSupply';

const vaultAddress = process.env.VAULT_ADDRESS;

const getCirculatingSupply = async (req, res) => {
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
    const vaultContract = new Contract(vaultAddress, BaseVault.abi, provider);

    // Fetch data
    const vaultInfo = await vaultContract.getVaultInfo();
    const circulatingSupply = vaultInfo[1];

    console.log({ vaultInfo })
    console.log(`Circulating Supply: ${ethers.formatUnits(circulatingSupply, 18)}`);

    // Cache and return result
    cache.put(CACHE_KEY, Number(ethers.formatUnits(circulatingSupply, 18)), CACHE_LIMIT);
    return res.send(cache.get(CACHE_KEY).toString());

  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
};

export default getCirculatingSupply;
