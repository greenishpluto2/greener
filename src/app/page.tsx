'use client';
import { useReadContract } from "thirdweb/react";
import { client } from "./client";
import { sepolia } from "thirdweb/chains";
import { getContract } from "thirdweb";
import { PoolCard } from "@/components/PoolCard";
import { CROWDFUNDING_FACTORY } from "./constants/contracts";

export default function Home() {
  // Get CrowdfundingFactory contract
  const contract = getContract({
    client: client,
    chain: sepolia,
    address: CROWDFUNDING_FACTORY,
  });

  // Get all campaigns deployed with CrowdfundingFactory
  const {data: pools, isLoading: isLoadingPools, refetch: refetchPools } = useReadContract({
    contract: contract,
    method: "function getAllCampaigns() view returns ((address campaignAddress, address owner, string name)[])",
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
                  key={pool.campaignAddress}
                  poolAddress={pool.campaignAddress}
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
