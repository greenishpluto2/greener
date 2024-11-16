'use client';
import { useReadContract } from "thirdweb/react";
import { client } from "./client";
import { sepolia } from "thirdweb/chains";
import { getContract } from "thirdweb";
import { PoolCard } from "@/components/PoolCard";
import { PREDICTION_MARKET_FACTORY } from "./constants/contracts";

export default function Home() {
  // Get CrowdfundingFactory contract
  const contract = getContract({
    client: client,
    chain: sepolia,
    address: PREDICTION_MARKET_FACTORY,
  });

  // Get all campaigns deployed with CrowdfundingFactory
  const {data: pools, isLoading: isLoadingPools, refetch: refetchPools } = useReadContract({
    contract: contract,
    method: "function getAllPools() view returns ((address poolAddress, address owner, string name, uint256 creationTime)[])",
    params: []
  });

  return (
    <main className="mx-auto max-w-7xl px-4 mt-4 sm:px-6 lg:px-8">
      <div className="py-10">
        <h1 className="text-4xl font-bold mb-4">Pools:</h1>
        <div className="grid grid-cols-3 gap-4">
          {!isLoadingPools && pools && (
            pools.length > 0 ? (
              pools.map((pool) => (
                <PoolCard
                  key={pool.poolAddress}
                  poolAddress={pool.poolAddress}
                />
              ))
            ) : (
              <p>No Campaigns</p>
            )
          )}
        </div>
      </div>
    </main>
  );
}
