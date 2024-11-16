'use client';
import { client } from "@/app/client";
import { CROWDFUNDING_FACTORY } from "@/app/constants/contracts";
import { MyPoolCard } from "@/components/MyPoolCard";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { getContract } from "thirdweb";
import { sepolia } from "thirdweb/chains";
import { deployPublishedContract } from "thirdweb/deploys";
import { useActiveAccount, useReadContract } from "thirdweb/react"

export default function DashboardPage() {
    const account = useActiveAccount();
    
    const [isModalOpen, setIsModalOpen] = useState<boolean>(false);

    const contract = getContract({
        client: client,
        chain: sepolia,
        address: CROWDFUNDING_FACTORY,
    });

    // Get Campaigns
    const { data: myPools, isLoading: isLoadingMyPools, refetch } = useReadContract({
        contract: contract,
        method: "function getUserCampaigns(address _user) view returns ((address campaignAddress, address owner, string name, uint256 creationTime)[])",
        params: [account?.address as string]
    });
    
    return (
        <div className="mx-auto max-w-7xl px-4 mt-16 sm:px-6 lg:px-8">
            <div className="flex flex-row justify-between items-center mb-8">
                <p className="text-4xl font-semibold">Dashboard</p>
                <Button
                    onClick={() => setIsModalOpen(true)}
                >Create a prediction pool</Button>
            </div>
            <p className="text-2xl font-semibold mb-4">My prediction pools:</p>
            <div className="grid grid-cols-3 gap-4">
                {!isLoadingMyPools && (
                    myPools && myPools.length > 0 ? (
                        myPools.map((pool, index) => (
                            <MyPoolCard
                                key={index}
                                contractAddress={pool.campaignAddress}
                            />
                        ))
                    ) : (
                        <p>No pools</p>
                    )
                )}
            </div>
            
            {isModalOpen && (
                <CreatePoolModal
                    setIsModalOpen={setIsModalOpen}
                    refetch={refetch}
                />
            )}
        </div>
    )
}

type CreatePoolModalProps = {
    setIsModalOpen: (value: boolean) => void
    refetch: () => void
}

const CreatePoolModal = (
    { setIsModalOpen, refetch }: CreatePoolModalProps
) => {
    const account = useActiveAccount();
    const [isDeployingContract, setIsDeployingContract] = useState<boolean>(false);
    const [poolName, setPoolName] = useState<string>("");
    const [campaignDescription, setPoolDescription] = useState<string>("");
    const [maxLimit, setCampaignGoal] = useState<number>(1);
    const [poolDeadline, setCampaignDeadline] = useState<number>(1);
    
    // Deploy contract from CrowdfundingFactory
    const handleDeployContract = async () => {
        setIsDeployingContract(true);
        try {
            console.log("Deploying contract...");
            const contractAddress = await deployPublishedContract({
                client: client,
                chain: sepolia,
                account: account!,
                contractId: "0x8fed78378216645fe64392acBaBa0e8c0114c875",
                contractParams: [
                    poolName,
                    campaignDescription,
                    maxLimit,
                    poolDeadline
                ],
                publisher: "0x8fed78378216645fe64392acBaBa0e8c0114c875"
            });
            alert("Contract deployed successfully!");
        } catch (error) {
            console.error(error);
        } finally {
            setIsDeployingContract(false);
            setIsModalOpen(false);
            refetch();
        }
    };

    const handlePoolGoal = (value: number) => {
        if (isNaN(value) || value < 0) {
            setCampaignGoal(0);
        } else {
            setCampaignGoal(value);
        }
    }

    const handlePoolLengthhange = (value: number) => {
        if (value < 1) {
            setCampaignDeadline(1);
        } else {
            setCampaignDeadline(value);
        }
    }

    return (
        <div className="fixed inset-0 bg-black bg-opacity-75 flex justify-center items-center backdrop-blur-md">
            <div className="w-1/2 bg-slate-100 p-6 rounded-md">
                <div className="flex justify-between items-center mb-4">
                    <p className="text-lg font-semibold">Create a prediciton pool</p>
                    <button
                        className="text-sm px-4 py-2 bg-slate-600 text-white rounded-md"
                        onClick={() => setIsModalOpen(false)}
                    >Close</button>
                </div>
                <div className="flex flex-col">
                    <label>Prediction Pool Name:</label>
                    <input 
                        type="text" 
                        value={poolName}
                        onChange={(e) => setPoolName(e.target.value)}
                        placeholder="Pool Name"
                        className="mb-4 px-4 py-2 bg-slate-300 rounded-md"
                    />
                    <label>Prediction Pool Description:</label>
                    <textarea
                        value={campaignDescription}
                        onChange={(e) => setPoolDescription(e.target.value)}
                        placeholder="Pool Description"
                        className="mb-4 px-4 py-2 bg-slate-300 rounded-md"
                    ></textarea>
                    <label>Pool max limit:</label>
                    <input 
                        type="number"
                        value={maxLimit}
                        onChange={(e) => handlePoolGoal(parseInt(e.target.value))}
                        min="0"
                        className="mb-4 px-4 py-2 bg-slate-300 rounded-md"
                    />
                    <label>{`Pool Length (Days)`}</label>
                    <div className="flex space-x-4">
                        <input 
                            type="number"
                            value={poolDeadline}
                            onChange={(e) => handlePoolLengthhange(parseInt(e.target.value))}
                            className="mb-4 px-4 py-2 bg-slate-300 rounded-md"
                        />
                    </div>

                    <Button
                        onClick={handleDeployContract}
                    >{
                        isDeployingContract ? "Creating pool..." : "Create Prediction Pool"
                    }</Button>
                    
                </div>
            </div>
        </div>
    )
}