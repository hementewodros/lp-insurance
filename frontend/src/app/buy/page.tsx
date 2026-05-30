"use client";

import { useAccount } from "wagmi";
import { useState } from "react";

export default function BuyInsurance() {
  const { isConnected } = useAccount();
  const [pool, setPool] = useState("");
  const [amount, setAmount] = useState("");

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center p-12">
        <h1 className="text-2xl font-bold mb-4">Buy Insurance</h1>
        <p className="text-gray-600 mb-8">Please connect your wallet to buy insurance.</p>
      </div>
    );
  }

  const handleBuy = (e: React.FormEvent) => {
    e.preventDefault();
    // Implementation for buying insurance
    console.log("Buying insurance for", pool, "amount", amount);
  };

  return (
    <div className="max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-6">Buy Liquidity Insurance</h1>
      
      <form onSubmit={handleBuy} className="bg-white p-6 rounded-lg shadow-sm border space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Pool Address
          </label>
          <input
            type="text"
            className="w-full p-2 border rounded focus:ring-blue-500 focus:border-blue-500"
            placeholder="0x..."
            value={pool}
            onChange={(e) => setPool(e.target.value)}
            required
          />
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Coverage Amount (ETH)
          </label>
          <input
            type="number"
            step="0.01"
            className="w-full p-2 border rounded focus:ring-blue-500 focus:border-blue-500"
            placeholder="0.00"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            required
          />
        </div>

        <div className="bg-blue-50 p-4 rounded text-sm text-blue-800">
          Estimated Premium: <strong>0.00 ETH</strong>
        </div>

        <button
          type="submit"
          className="w-full bg-blue-600 text-white font-semibold py-2 px-4 rounded hover:bg-blue-700 transition-colors"
        >
          Purchase Coverage
        </button>
      </form>
    </div>
  );
}
