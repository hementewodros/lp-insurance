"use client";

import { useAccount } from "wagmi";

export default function Dashboard() {
  const { address, isConnected } = useAccount();

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center p-12">
        <h1 className="text-2xl font-bold mb-4">Welcome to LiquiShield</h1>
        <p className="text-gray-600 mb-8">Please connect your wallet to view your dashboard.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Your Dashboard</h1>
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-lg font-semibold mb-4">Overview</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="p-4 bg-gray-50 rounded border">
            <div className="text-sm text-gray-500">Liquidity Provided</div>
            <div className="text-xl font-bold mt-1">$0.00</div>
          </div>
          <div className="p-4 bg-gray-50 rounded border">
            <div className="text-sm text-gray-500">Active Coverage</div>
            <div className="text-xl font-bold mt-1">$0.00</div>
          </div>
          <div className="p-4 bg-gray-50 rounded border">
            <div className="text-sm text-gray-500">Current IL</div>
            <div className="text-xl font-bold mt-1 text-red-500">$0.00</div>
          </div>
        </div>
      </div>
      
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-lg font-semibold mb-4">Your Positions</h2>
        <div className="text-center text-gray-500 py-8">
          No active positions found.
        </div>
      </div>
    </div>
  );
}
