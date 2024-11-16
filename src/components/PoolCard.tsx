import { client } from "@/app/client";
import Link from "next/link";
import { getContract } from "thirdweb";
import { sepolia } from "thirdweb/chains";
import { useReadContract } from "thirdweb/react";
import { ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";

type PoolCardProps = {
    poolAddress: string;
};

export const PoolCard: React.FC<PoolCardProps> = ({ poolAddress: poolAddress }) => {
    const contract = getContract({
        client: client,
        chain: sepolia,
        address: poolAddress,
    });

    // Get Campaign Name
    const { data: campaignName } = useReadContract({
        contract: contract,
        method: "function name() view returns (string)",
        params: []
    });

    // Get Campaign Description
    const { data: campaignDescription } = useReadContract({
        contract: contract,
        method: "function description() view returns (string)",
        params: []
    });

    // Goal amount of the campaign
    const { data: goal, isLoading: isLoadingGoal } = useReadContract({
        contract: contract,
        method: "function goal() view returns (uint256)",
        params: [],
    });

    // Total funded balance of the campaign
    const { data: balance, isLoading: isLoadingBalance } = useReadContract({
        contract: contract,
        method: "function getContractBalance() view returns (uint256)",
        params: [],
    });

    return (
        <div className="flex flex-col justify-between max-w-sm p-6 bg-white border border-slate-200 rounded-lg shadow">
            <div>


                <h5 className="mb-2 text-2xl font-bold tracking-tight">{campaignName}</h5>

                <p className="mb-3 font-normal text-gray-700 dark:text-gray-400">{campaignDescription}</p>
                <div className="space-y-2 mb-4">
                    <div className="text-xl font-bold">
                        <span>Pool size </span>
                        <span>${balance?.toString()}</span>
                    </div>
                    <div className="text-sm text-muted-foreground flex justify-between">
                        <span>Limit: </span>
                        <span>
                            {goal === 0n ? "No limit" : `$${goal?.toString()}`}
                        </span>
                    </div>
                </div> </div>

            <Button asChild>
                <Link href={`/pool/${poolAddress}`}>
                    View prediction pool
                    <ArrowRight className="ml-2 h-4 w-4" />
                </Link>
            </Button>
        </div>
    )
};