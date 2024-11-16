import { client } from "@/app/client";
import Link from "next/link";
import { getContract } from "thirdweb";
import { sepolia } from "thirdweb/chains";
import { useReadContract } from "thirdweb/react";
import { Button } from "@/components/ui/button";

type MyPoolCardProps = {
    contractAddress: string;
};

export const MyPoolCard: React.FC<MyPoolCardProps> = ({ contractAddress }) => {
    const contract = getContract({
        client: client,
        chain: sepolia,
        address: contractAddress,
    });

    // Get Campaign Name
    const { data: name } = useReadContract({
        contract, 
        method: "function name() view returns (string)", 
        params: []
    });

    const { data: description } = useReadContract({ 
        contract, 
        method: "function description() view returns (string)", 
        params: [] 
      });

    return (
            <div className="flex flex-col justify-between max-w-sm p-6 bg-white border border-slate-200 rounded-lg shadow">
                <div>
                    <h5 className="mb-2 text-2xl font-bold tracking-tight">{name}</h5>
                    <p className="mb-3 font-normal text-gray-700 dark:text-gray-400">{description}</p>
                </div>
                
                <Link
                    href={`/pool/${contractAddress}`}
                    passHref={true}
                >
                    <Button className="w-full">
                        View Pool
                        <svg className="w-4 h-4 ml-2" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 14 10">
                            <path stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M1 5h12m0 0L9 1m4 4L9 9"/>
                        </svg>
                    </Button>
                </Link>
            </div>
    )
};