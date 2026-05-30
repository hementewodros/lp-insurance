"use client";

import { useAccount } from "wagmi";

export default function Claim() {
  const { isConnected } = useAccount();

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center p-12">
        <h1 className="text-2xl font-bold mb-4">Claim Insurance</h1>
        <p className="text-gray-600 mb-8">Please connect your wallet to view or make claims.</p>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Claim Insurance</h1>
      
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-lg font-semibold mb-4">Eligible Policies</h2>
        <div className="text-center text-gray-500 py-8 border-2 border-dashed rounded">
          No policies eligible for claims at this time.
          <br/>
          <span className="text-sm mt-2 block">
            Policies become eligible when Impermanent Loss exceeds your coverage threshold.
          </span>
        </div>
      </div>
      
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-lg font-semibold mb-4">Claim History</h2>
        <div className="text-center text-gray-500 py-4">
          No previous claims found.
        </div>
      </div>
    </div>
  );
}
