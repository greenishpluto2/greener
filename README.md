# Greenish Pluto Prediction Market App

A decentralized prediction market platform built on Sepolia testnet.

## 🚀 Technologies

- **Frontend**: Next.js with thirdweb template
- **Smart Contracts**: Solidity + Hardhat
- **Blockchain**: Sepolia testnet
- **Block Explorer**: Blockscout

## 🔗 Smart Contracts and Frontend

The smart contracts are deployed on Sepolia testnet and can be viewed on Blockscout explorer with verified code:
[View Contract on Blockscout](https://eth-sepolia.blockscout.com/address/0xfBA3Bc29b7323Fb685403C000644ed9126cF0ecD?tab=contract)

All code (frontend and backend) is available on [GitHub](https://github.com/greenishpluto2/greener)

Frontend is deployed on Netlify:
[Open App](https://glowing-hotteok-19562e.netlify.app/)


## 🌐 Features

- Create prediction market pools
- Participate in predictions
- Real-time balance tracking
- Integrated with Sepolia testnet
- Transparent transaction history via Blockscout

## Blockscout support

The app uses links to the Blockscout explorer to provide transparency into the transaction history. Also contract code is verified on Blockscout. Such a link can be seen for example here:
[Blockscout link in the app](https://glowing-hotteok-19562e.netlify.app/pool/0x870b68f0F51906939Ab1D7222116e793f50DD783)

## Pyth and Chronicle Oracle support with Pyth Entropy random number generation
A new version of the contracts deployed on Base Sepolia testnet:
[View Contract on Blockscout](https://base-sepolia.blockscout.com/address/0x8fed78378216645fe64392acBaBa0e8c0114c875?tab=contract)

The contracts are compatible with the Pyth and Chronicle Oracle networks and use the Pyth Entropy random number generator to generate random numbers to break ties for a special type of prediciton pools. The updated contracts add additional functionality to create and manage prediction pools.

### Additional Features

- The pool creator can set the pool type to either "Proportional" or "Single"
* Single pool winner will be determined by random number generation by Pyth amongst all who have bet on the winning outcome
* Proportional pool winner will be determined by the ratio of bets on the winning outcome to the total bets on all outcomes
- The pool creator can set how the winner will be determined, whether by certain address (i.e. owner of the pool) or by price oracle Pyth or oracle Chronicle
- Each pool outcome has a value associated with it, which can be used to determine the winner by determining which outcome is closest to the value provided by the oracle
- Current implementation uses the Pyth price feed for QQQ (i.e. Nasdaq-100 Index) and Chronicle price feed for ETH/USD

### Base Sepolia Testnet Deployment

The smart contracts are deployed on Base Sepolia testnet and can be viewed on Blockscout explorer with verified code:
[View Contract on Blockscout](https://base-sepolia.blockscout.com/address/0x8fed78378216645fe64392acBaBa0e8c0114c875?tab=contract)

Since the frontend is deployed on a different chain (base Sepolia), the frontend code is slightly modified but the implementation of resolving of the prediction outcome by the oracle has not been implemented yet due to time constraints. However, using the thirdweb web console, the contract functionality has been tested. The implementation of fetching Hermes price is done in the frontend for Base Sepolia which has not been deployed yet. The code fragment for fetching the Hermes price is shown below and submitting the price to the contract:

This is part of the file: 
src/
├── app/
│   └── dashboard/
│       └── [walletAddress]/
│           └── page.tsx

```javascript
const CreatePoolModal = (...
...
    const submitPythPriceToContract = async () => {
        try {
            const hermesClient = new HermesClient("https://hermes.pyth.network", {});
            const priceIds = [pythPriceFeedId]; // Using the state variable
            
            const priceUpdates = await hermesClient.getLatestPriceUpdates(priceIds);
            const parsedData = priceUpdates.parsed[0];
            const rawPrice = parsedData.price.price;
            const expo = parsedData.price.expo;
            
            const adjustedPrice = rawPrice / Math.pow(10, Math.abs(expo));
            console.log(`Adjusted Price: ${adjustedPrice}`);
            
            // Convert binary data to bytes array for contract
            const pythUpdateData = priceUpdates.binary.data;
            
            // Call the contract method
            const tx = await prepareContractCall({
                contract: factoryContract,
                method: "function resolveWithPyth(bytes[] calldata pythUpdateData)",
                params: [pythUpdateData],
                value: updateFee, // You'll need to get this from the contract
            });
            
            return tx;
        } catch (error) {
            console.error("Error submitting Pyth price:", error);
            throw error;
        }
    };

``` 


