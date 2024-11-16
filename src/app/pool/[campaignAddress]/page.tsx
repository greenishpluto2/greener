'use client';
import { client } from "@/app/client";
import { OutcomeCard } from "@/components/OutcomeCard";
import { Button } from "@/components/ui/button";
import { useParams } from "next/navigation";
import { useState } from "react";
import { getContract, prepareContractCall, ThirdwebContract } from "thirdweb";
import { sepolia } from "thirdweb/chains";
import { lightTheme, TransactionButton, useActiveAccount, useReadContract } from "thirdweb/react";

export default function CampaignPage() {
    const account = useActiveAccount();
    const { campaignAddress } = useParams();
    const [isEditing, setIsEditing] = useState<boolean>(false);
    const [isModalOpen, setIsModalOpen] = useState<boolean>(false);

    const contract = getContract({
        client: client,
        chain: sepolia,
        address: campaignAddress as string,
    });

    // Name of the campaign
    const { data: name, isLoading: isLoadingName } = useReadContract({
        contract: contract,
        method: "function name() view returns (string)",
        params: [],
    });

    // Description of the campaign
    const { data: description } = useReadContract({ 
        contract, 
        method: "function description() view returns (string)", 
        params: [] 
      });

    // Campaign deadline
    const { data: deadline, isLoading: isLoadingDeadline } = useReadContract({
        contract: contract,
        method: "function deadline() view returns (uint256)",
        params: [],
    });
    // Convert deadline to a date
    const deadlineDate = new Date(parseInt(deadline?.toString() as string) * 1000);
    // Check if deadline has passed
    const hasDeadlinePassed = deadlineDate < new Date();

    // Goal amount of the pool
    const { data: predictedAmount, isLoading: isLoadingPredictedAmount } = useReadContract({
        contract: contract,
        method: "function totalPredictionAmount() view returns (uint256)",
        params: [],
    });
    
    // Total funded balance of the pool
    const { data: balance, isLoading: isLoadingBalance } = useReadContract({
        contract: contract,
        method: "function getContractBalance() view returns (uint256)",
        params: [],
    });

    // Get Outcomes for the pool
    const { data: outcomes, isLoading: isLoadingOutcomes } = useReadContract({
        contract: contract,
        method: "function getOutcomes() view returns ((string name, uint256 totalBets, uint256 initialProbability)[])",
        params: [],
    });

    // Get owner of the pool
    const { data: owner, isLoading: isLoadingOwner } = useReadContract({
        contract: contract,
        method: "function owner() view returns (address)",
        params: [],
    });

    // Get status of the pool
    const { data: status } = useReadContract({ 
        contract, 
        method: "function getPoolStatus() view returns (uint8)", 
        params: [] 
      });
    
    return (
        <div className="mx-auto max-w-7xl px-2 mt-4 sm:px-6 lg:px-8">
            <div className="flex flex-row justify-between items-center">
                {!isLoadingName && (
                    <p className="text-4xl font-semibold">{name}</p>
                )}
                {owner === account?.address && (
                    <div className="flex flex-row">
                        {isEditing && (
                            <p className="px-4 py-2 bg-gray-500 text-white rounded-md mr-2">
                                Status:  
                                {status === 0 ? " Active" : 
                                status === 1 ? " Successful" :
                                status === 2 ? " Failed" : "Unknown"}
                            </p>
                        )}
                        <Button
                            onClick={() => setIsEditing(!isEditing)}
                        >{isEditing ? "Done" : "Edit"}</Button>
                    </div>
                )}
            </div>
            <div className="my-4">
                <p className="text-lg font-semibold">Description:</p>
                <p>{description}</p>
            </div>
            <div className="mb-4">
                <p className="text-lg font-semibold">Deadline</p>
                {!isLoadingDeadline && (
                    <p>{deadlineDate.toDateString()}</p>
                )}
            </div>
            {!isLoadingBalance && (
                <div className="mb-4">
                    <p className="text-lg font-semibold">Current Balance: ${balance?.toString()}</p>
                </div>
            )}
            <div className="mb-4">
                <a 
                    href={`https://eth-sepolia.blockscout.com/address/${campaignAddress}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-500 hover:text-blue-700 underline"
                >
                    View on Blockscout block explorer
                </a>
            </div>
            <div>
                <p className="text-lg font-semibold">Choose outcome:</p>
                <div className="grid grid-cols-3 gap-4">
                    {isLoadingOutcomes ? (
                        <p >Loading...</p>
                    ) : (
                        outcomes && outcomes.length > 0 ? (
                            outcomes.map((outcome, index) => {
                                return (
                                    <OutcomeCard
                                        key={index}
                                        outcome={{
                                            name: outcome.name,
                                            totalBets: outcome.totalBets,
                                            initialProbability: outcome.initialProbability
                                        }}
                                        index={index}
                                        contract={contract}
                                        isEditing={isEditing}
                                    />
                                );
                            })
                        ) : (
                            !isEditing && (
                                <p>No outcomes specified</p>
                            )
                        )
                    )}
                    {isEditing && (
                        // Add a button card with text centered in the middle
                        <Button                           
                            onClick={() => setIsModalOpen(true)}
                        >+ Add Outcome</Button>
                    )}
                </div>
            </div>
            
            {isModalOpen && (
                <CreateOutcomelModal
                    setIsModalOpen={setIsModalOpen}
                    contract={contract}
                />
            )}
        </div>
    );
}

type CreateOutcomeModalProps = {
    setIsModalOpen: (value: boolean) => void
    contract: ThirdwebContract
}

const CreateOutcomelModal = (
    { setIsModalOpen, contract }: CreateOutcomeModalProps
) => {
    const [outcomeName, setOutcomeName] = useState<string>("");
    const [outcomeProbability, setOutcomeProbability] = useState<bigint>(1n);

    return (
        <div className="fixed inset-0 bg-black bg-opacity-75 flex justify-center items-center backdrop-blur-md">
            <div className="w-1/2 bg-slate-100 p-6 rounded-md">
                <div className="flex justify-between items-center mb-4">
                    <p className="text-lg font-semibold">Create an Outcome</p>
                    <button
                        className="text-sm px-4 py-2 bg-slate-600 text-white rounded-md"
                        onClick={() => setIsModalOpen(false)}
                    >Close</button>
                </div>
                <div className="flex flex-col">
                    <label>Outcome Name:</label>
                    <input 
                        type="text" 
                        value={outcomeName}
                        onChange={(e) => setOutcomeName(e.target.value)}
                        placeholder="Outcome Name"
                        className="mb-4 px-4 py-2 bg-slate-200 rounded-md"
                    />
                    <label>Outcome Initial Probability:</label>
                    <input 
                        type="number"
                        value={parseInt(outcomeProbability.toString())}
                        onChange={(e) => setOutcomeProbability(BigInt(e.target.value))}
                        className="mb-4 px-4 py-2 bg-slate-200 rounded-md"
                    />
                    <TransactionButton
                        transaction={() => prepareContractCall({
                            contract: contract,
                            method: "function addOutcome(string _name, uint256 _initialProbability)",
                            params: [outcomeName, outcomeProbability]
                        })}
                        onTransactionConfirmed={async () => {
                            alert("Outcome added successfully!")
                            setIsModalOpen(false)
                        }}
                        onError={(error) => alert(`Error: ${error.message}`)}
                        theme={lightTheme()}
                    >Add Outcome</TransactionButton>
                </div>
            </div>
        </div>
    )
}