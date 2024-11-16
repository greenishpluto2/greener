import { useState } from "react";
import { prepareContractCall, ThirdwebContract } from "thirdweb";
import { TransactionButton } from "thirdweb/react";
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input";
import { parseEther } from "viem";

type Outcome = {
    name: string;
    totalBets: bigint;
    initialProbability: bigint;
};

type OutcomeCardProps = {
    outcome: Outcome;
    index: number;
    contract: ThirdwebContract
    isEditing: boolean;
}

export const OutcomeCard: React.FC<OutcomeCardProps> = ({ outcome, index, contract, isEditing }) => {
    const [amount, setAmount] = useState<string>("");
    const [error, setError] = useState<string>("");

/*     console.log('Outcome Card Props:', {
        name: outcome.name,
        totalBets: outcome.totalBets.toString(),
        initialProbability: outcome.initialProbability.toString(),
        index: index,
        isEditing: isEditing
    }); */

    const validateAndConvertAmount = () => {
        if (!amount) {
            setError("Please enter an amount");
            return null;
        }

        const numAmount = Number(amount);
        if (isNaN(numAmount) || numAmount <= 0 || !Number.isInteger(numAmount)) {
            setError("Please enter a positive integer");
            return null;
        }
        setError("");
        // Convert to a tiny fraction of Wei (1 Wei = 1e-18 ETH)
        return BigInt(numAmount); // Returns just 1 Wei regardless of input
    };

    return (
        <div className="max-w-sm flex flex-col justify-between p-6 bg-white border border-slate-100 rounded-lg shadow">
            <div>
                <div className="flex flex-row justify-between items-center gap-4">
                    <div className="flex flex-col gap-1">
                        <p className="text-2xl font-semibold shrink-0">{outcome.name}</p>
                        <p className="text-sm font-semibold text-gray-500">Bets: ${outcome.totalBets.toString()}</p>
                    </div>
                    <Input
                        type="number"
                        placeholder="Fake $ amount"
                        onChange={(e) => setAmount(e.target.value)}
                        min="1"
                        step="1"
                        className={`w-32 ${error ? "border-red-500" : ""}`}
                    />
                </div>
            </div>
            <div className="flex flex-row justify-between items-end">
                
                <div className="mt-4 space-y-2">

                    {error && <p className="text-sm text-red-500">{error}</p>}
                    <Button
                        variant="destructive"
                        asChild
                        className="w-full hover:bg-red-700 transition-colors"
                    >
                        <TransactionButton
                            transaction={async () => {
                                const weiAmount = validateAndConvertAmount();
                                if (!weiAmount) throw new Error("Invalid amount");

                                return prepareContractCall({
                                    contract: contract,
                                    method: "function placeBet(uint256 _outcomeIndex) payable",
                                    params: [BigInt(index)],
                                    value: weiAmount,
                                });
                            }}
                            onError={(error) => alert(`Error: ${error.message}`)}
                            onTransactionConfirmed={async () => {
                                alert("Predicted successfully!");
                                setAmount("");
                            }}
                        >
                            Predict
                        </TransactionButton>
                    </Button>
                </div>
            </div>
            {isEditing && (
                <Button
                    variant="destructive"
                    asChild
                    className="hover:bg-red-700 transition-colors"
                >
                    <TransactionButton
                        transaction={() => prepareContractCall({
                            contract: contract,
                            method: "function removeOutcome(uint256 _index)",
                            params: [BigInt(index)],
                        })}
                        onError={(error) => alert(`Error: ${error.message}`)}
                        onTransactionConfirmed={async () => alert("Removed successfully!")}
                    >Remove</TransactionButton>
                </Button>
            )}
        </div>
    )
};