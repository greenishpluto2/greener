import { useState } from "react";
import { prepareContractCall, ThirdwebContract } from "thirdweb";
import { TransactionButton } from "thirdweb/react";
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input";
import { parseEther } from "viem";

type Tier = {
    name: string;
    amount: bigint;
    backers: bigint;
};

type TierCardProps = {
    tier: Tier;
    index: number;
    contract: ThirdwebContract
    isEditing: boolean;
}

export const TierCard: React.FC<TierCardProps> = ({ tier, index, contract, isEditing }) => {
    const [amount, setAmount] = useState<string>("");
    const [error, setError] = useState<string>("");

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
        return parseEther(amount); // Converts ETH to Wei
    };

    return (
        <div className="max-w-sm flex flex-col justify-between p-6 bg-white border border-slate-100 rounded-lg shadow">
            <div>
                <div className="flex flex-row justify-between items-center gap-4">
                    <p className="text-2xl font-semibold shrink-0">{tier.name}</p>
                    <Input
                        type="number"
                        placeholder="Enter amount in ETH"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        min="1"
                        step="1"
                        className={`w-32 ${error ? "border-red-500" : ""}`}
                    />
                </div>
            </div>
            <div className="flex flex-row justify-between items-end">
                <p className="text-xs font-semibold">Total bets: {tier.backers.toString()}</p>
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
                                    method: "function fund(uint256 _tierIndex) payable",
                                    params: [BigInt(index)],
                                    value: weiAmount,
                                });
                            }}
                            onError={(error) => alert(`Error: ${error.message}`)}
                            onTransactionConfirmed={async () => {
                                alert("Funded successfully!");
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
                            method: "function removeTier(uint256 _index)",
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