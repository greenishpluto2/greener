// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title PredictionPoolOracle
 * @dev A contract that allows users to bet on different outcomes of a prediction event.
 *      The pool creator can choose the settlement type and winner distribution method.
 */

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol"; // Import PythStructs
import "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

// Interface for Chronicle Oracle
interface IChronicle {
    function read() external view returns (uint256 value);
    function readWithAge() external view returns (uint256 value, uint256 age);
}

contract PredictionPoolOracle is IEntropyConsumer {
    // Basic pool information
    string public name;             // Name of the prediction pool
    string public description;      // Description of the prediction pool
    uint256 public maxLimit;        // Optional maximum limit for total bets (0 for no limit)
    uint256 public deadline;        // Betting deadline timestamp
    address public owner;           // Owner of the prediction pool
    bool public paused;             // Indicates if the contract is paused
    bool public resolved;           // Indicates if the pool has been resolved
    uint256 public winningOutcomeIndex; // Index of the winning outcome

    // Settlement types
    enum SettlementType { Wallet, Pyth, Chronicle }
    SettlementType public settlementType;

    // Possible states of the prediction pool
    enum PoolState { Open, Closed, Resolving, Resolved }
    PoolState public state;         // Current state of the pool

    // Pool winner type
    enum WinnerType { Proportional, Single }
    WinnerType public winnerType;    // Winner distribution type

    /**
     * @dev Structure representing each prediction outcome.
     * @param name Name of the outcome.
     * @param totalBets Total amount bet on this outcome.
     * @param initialProbability Initial probability set by the pool creator (in basis points, 0 to 10000).
     * @param value Numeric value associated with the outcome.
     */
    struct PredictionOutcome {
        string name;
        uint256 totalBets;
        uint256 initialProbability; // In basis points (0 to 10000)
        uint256 value;              // Numeric value associated with the outcome
    }

    /**
     * @dev Structure representing a bettor's bets.
     * @param bets Mapping from outcome index to the amount bet by the bettor.
     * @param claimed Indicates if the bettor has claimed their winnings.
     */
    struct Bettor {
        mapping(uint256 => uint256) bets; // outcomeIndex => amount
        bool claimed;
    }

    // Arrays and mappings
    PredictionOutcome[] public outcomes;            // Array of prediction outcomes
    mapping(address => Bettor) public bettors;      // Mapping of bettors' addresses to their bets

    // New mappings to keep track of bettors per outcome
    mapping(uint256 => address[]) public bettorsPerOutcome; // outcomeIndex => list of bettors
    mapping(uint256 => mapping(address => bool)) private hasBettorBetOnOutcome; // outcomeIndex => bettor => bool

    // Pyth Entropy variables
    IEntropy public entropy;                 // Entropy contract interface
    address public providerAddress;          // Entropy provider address
    uint64 public entropySequenceNumber;     // Sequence number for entropy request
    bytes32 public randomNumber;             // Random number received from entropy

    // Pyth Oracle variables
    IPyth public pyth;
    bytes32 public pythPriceFeedId;

    // Chronicle Oracle variables
    IChronicle public chronicle;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier poolOpen() {
        if (state == PoolState.Open && block.timestamp >= deadline) {
            state = PoolState.Closed;
        }
        require(state == PoolState.Open, "Pool is not open for betting.");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract is paused.");
        _;
    }

    // Events
    event BetPlaced(address indexed bettor, uint256 outcomeIndex, uint256 amount);
    event OutcomeResolved(uint256 winningOutcomeIndex);
    event WinningsClaimed(address indexed bettor, uint256 amount);
    event RandomnessRequested(uint64 sequenceNumber);
    event RandomnessReceived(bytes32 randomNumber);

    /**
     * @dev Constructor to initialize the prediction pool.
     * @param _owner Address of the pool owner.
     * @param _name Name of the prediction pool.
     * @param _description Description of the prediction pool.
     * @param _maxLimit Maximum total bets allowed (0 for no limit).
     * @param _durationInDays Duration of the betting period in days.
     * @param _winnerType Winner distribution type (0 for Proportional, 1 for Single).
     * @param _settlementType Settlement type (0 for Wallet, 1 for Pyth, 2 for Chronicle).
     * @param _entropyAddress Address of the Pyth Entropy contract (if winnerType is Single).
     * @param _providerAddress Address of the entropy provider (if winnerType is Single).
     * @param _pythAddress Address of the Pyth contract (if settlementType is Pyth).
     * @param _pythPriceFeedId Price feed ID for Pyth (if settlementType is Pyth).
     * @param _chronicleAddress Address of the Chronicle oracle (if settlementType is Chronicle).
     */
    constructor(
        address _owner,
        string memory _name,
        string memory _description,
        uint256 _maxLimit,
        uint256 _durationInDays,
        WinnerType _winnerType,
        SettlementType _settlementType,
        address _entropyAddress,
        address _providerAddress,
        address _pythAddress,
        bytes32 _pythPriceFeedId,
        address _chronicleAddress
    ) {
        name = _name;
        description = _description;
        maxLimit = _maxLimit;
        deadline = block.timestamp + (_durationInDays * 1 days);
        owner = _owner;
        state = PoolState.Open;
        winnerType = _winnerType;
        settlementType = _settlementType;

        // Initialize Pyth Entropy if winnerType is Single
        if (_winnerType == WinnerType.Single) {
            entropy = IEntropy(_entropyAddress);
            providerAddress = _providerAddress;
        }

        // Initialize Pyth Oracle if settlementType is Pyth
        if (_settlementType == SettlementType.Pyth) {
            pyth = IPyth(_pythAddress);
            pythPriceFeedId = _pythPriceFeedId;
        }

        // Initialize Chronicle Oracle if settlementType is Chronicle
        if (_settlementType == SettlementType.Chronicle) {
            chronicle = IChronicle(_chronicleAddress);
        }
    }

    /**
     * @dev Required by the IEntropyConsumer interface to get the entropy contract address.
     * @return Address of the entropy contract.
     */
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    /**
     * @dev Adds a new prediction outcome to the pool.
     * @param _name Name of the prediction outcome.
     * @param _initialProbability Initial probability in basis points (0 to 10000).
     * @param _value Numeric value associated with the outcome.
     */
    function addOutcome(
        string memory _name,
        uint256 _initialProbability,
        uint256 _value
    ) public onlyOwner {
        require(
            _initialProbability <= 10000,
            "Probability must be between 0 and 10000."
        );
        outcomes.push(PredictionOutcome(_name, 0, _initialProbability, _value));
    }

    /**
     * @dev Removes an existing prediction outcome from the pool.
     * @param _index Index of the outcome to remove.
     */
    function removeOutcome(uint256 _index) public onlyOwner {
        require(_index < outcomes.length, "Outcome does not exist.");
        outcomes[_index] = outcomes[outcomes.length - 1];
        outcomes.pop();
    }

    /**
     * @dev Allows a user to place a bet on a specific outcome.
     * @param _outcomeIndex Index of the outcome to bet on.
     */
    function placeBet(uint256 _outcomeIndex)
        public
        payable
        poolOpen
        notPaused
    {
        require(_outcomeIndex < outcomes.length, "Invalid outcome.");
        require(msg.value > 0, "Bet amount must be greater than zero.");

        if (maxLimit > 0) {
            require(
                address(this).balance <= maxLimit,
                "Max limit reached."
            );
        }

        Bettor storage bettor = bettors[msg.sender];

        // Add bettor to the list for the outcome if not already added
        if (!hasBettorBetOnOutcome[_outcomeIndex][msg.sender]) {
            bettorsPerOutcome[_outcomeIndex].push(msg.sender);
            hasBettorBetOnOutcome[_outcomeIndex][msg.sender] = true;
        }

        bettor.bets[_outcomeIndex] += msg.value;
        outcomes[_outcomeIndex].totalBets += msg.value;

        emit BetPlaced(msg.sender, _outcomeIndex, msg.value);
    }

    /**
     * @dev Calculates and returns the current probabilities of each outcome based on bets placed.
     * @return probabilities Array of probabilities in basis points (0 to 10000).
     */
    function getProbabilities() public view returns (uint256[] memory) {
        uint256[] memory probabilities = new uint256[](outcomes.length);
        uint256 totalBets = getContractBalance();

        for (uint256 i = 0; i < outcomes.length; i++) {
            if (totalBets > 0) {
                probabilities[i] = (outcomes[i].totalBets * 10000) / totalBets;
            } else {
                probabilities[i] = outcomes[i].initialProbability;
            }
        }

        return probabilities;
    }

    /**
     * @dev Manually closes betting after the deadline has passed.
     */
    function closeBetting() public onlyOwner {
        require(state == PoolState.Open, "Betting already closed.");
        require(block.timestamp >= deadline, "Deadline not reached yet.");
        state = PoolState.Closed;
    }

    /**
     * @dev Resolves the pool based on the settlement type.
     * @param _winningOutcomeIndex Index of the winning outcome (required if settlementType is Wallet).
     * @param pythUpdateData Price update data for Pyth oracle (required if settlementType is Pyth).
     */
    function resolve(
        uint256 _winningOutcomeIndex,
        bytes[] calldata pythUpdateData
    ) public payable onlyOwner {
        require(state == PoolState.Closed, "Betting not closed yet.");
        require(!resolved, "Outcome already resolved.");

        if (settlementType == SettlementType.Wallet) {
            require(
                _winningOutcomeIndex < outcomes.length,
                "Invalid outcome index."
            );
            winningOutcomeIndex = _winningOutcomeIndex;
            _afterResolve();
        } else if (settlementType == SettlementType.Pyth) {
            _resolveWithPyth(pythUpdateData);
        } else if (settlementType == SettlementType.Chronicle) {
            _resolveWithChronicle();
        }
    }

    /**
     * @dev Internal function to resolve the pool using Pyth oracle.
     * @param pythUpdateData Price update data for Pyth oracle.
     */
    function _resolveWithPyth(bytes[] calldata pythUpdateData) internal {
        uint256 updateFee = pyth.getUpdateFee(pythUpdateData);
        require(msg.value >= updateFee, "Insufficient fee for price update.");

        pyth.updatePriceFeeds{value: updateFee}(pythUpdateData);

        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            pythPriceFeedId,
            60 // Accept price update within last 60 seconds
        );

        uint256 oracleValue = _toUint256Price(price);

        winningOutcomeIndex = _getClosestOutcomeIndex(oracleValue);
        _afterResolve();
    }

    /**
     * @dev Internal function to resolve the pool using Chronicle oracle.
     */
    function _resolveWithChronicle() internal {
        (uint256 value, uint256 age) = chronicle.readWithAge();
        require(age + 60 >= block.timestamp, "Stale price data.");

        uint256 oracleValue = value;

        winningOutcomeIndex = _getClosestOutcomeIndex(oracleValue);
        _afterResolve();
    }

    /**
     * @dev Converts Pyth price to uint256.
     * @param price Pyth price struct.
     * @return uint256 representation of the price.
     */
    function _toUint256Price(PythStructs.Price memory price)
        internal
        pure
        returns (uint256)
    {
        int64 priceValue = price.price;
        int32 expo = price.expo;

        // Handle negative and positive exponents
        if (expo < 0) {
            return uint256(int256(priceValue)) * (10 ** uint32(-expo));
        } else {
            return uint256(int256(priceValue)) / (10 ** uint32(expo));
        }
    }

    /**
     * @dev Finds the index of the outcome closest to the oracle value.
     * @param oracleValue The value obtained from the oracle.
     * @return Index of the closest outcome.
     */
    function _getClosestOutcomeIndex(uint256 oracleValue)
        internal
        view
        returns (uint256)
    {
        uint256 closestIndex = 0;
        uint256 smallestDifference = type(uint256).max;

        for (uint256 i = 0; i < outcomes.length; i++) {
            uint256 outcomeValue = outcomes[i].value;
            uint256 difference = oracleValue > outcomeValue
                ? oracleValue - outcomeValue
                : outcomeValue - oracleValue;

            if (difference < smallestDifference) {
                smallestDifference = difference;
                closestIndex = i;
            }
        }

        return closestIndex;
    }

    /**
     * @dev Handles post-resolution actions.
     */
    function _afterResolve() internal {
        if (winnerType == WinnerType.Single) {
            // Request randomness from Pyth Entropy
            uint128 requestFee = entropy.getFee(providerAddress);
            require(
                address(this).balance >= requestFee,
                "Insufficient balance for entropy fee."
            );

            // User-provided randomness can be zero in this case
            bytes32 userRandomNumber = keccak256(
                abi.encodePacked(block.timestamp, blockhash(block.number - 1))
            );
            entropySequenceNumber = entropy.requestWithCallback{value: requestFee}(
                providerAddress,
                userRandomNumber
            );

            emit RandomnessRequested(entropySequenceNumber);

            state = PoolState.Resolving;
        } else {
            state = PoolState.Resolved;
            resolved = true;
            emit OutcomeResolved(winningOutcomeIndex);
        }
    }

    /**
     * @dev Callback function required by IEntropyConsumer interface.
     *      Receives the random number from Pyth Entropy.
     * @param _sequenceNumber Sequence number of the request.
     * @param _providerAddress Address of the entropy provider.
     * @param _randomNumber Random number received.
     */
    function entropyCallback(
        uint64 _sequenceNumber,
        address _providerAddress,
        bytes32 _randomNumber
    ) internal override {
        require(state == PoolState.Resolving, "Not in resolving state.");
        require(!resolved, "Already resolved.");
        require(_sequenceNumber == entropySequenceNumber, "Invalid sequence number.");
        require(_providerAddress == providerAddress, "Invalid provider.");

        randomNumber = _randomNumber;
        emit RandomnessReceived(_randomNumber);

        state = PoolState.Resolved;
        resolved = true;

        emit OutcomeResolved(winningOutcomeIndex);
    }

    /**
     * @dev Allows bettors who bet on the winning outcome to claim their winnings.
     */
    function claimWinnings() public {
        require(state == PoolState.Resolved, "Outcome not resolved yet.");
        require(!bettors[msg.sender].claimed, "Winnings already claimed.");

        Bettor storage bettor = bettors[msg.sender];
        uint256 winningBet = bettor.bets[winningOutcomeIndex];
        require(winningBet > 0, "No winning bet to claim.");

        uint256 payout;

        if (winnerType == WinnerType.Proportional) {
            uint256 totalWinningBets = outcomes[winningOutcomeIndex].totalBets;
            uint256 totalPoolBets = getContractBalance();

            payout = (winningBet * totalPoolBets) / totalWinningBets;
        } else if (winnerType == WinnerType.Single) {
            // Select a single winner using the random number
            address winner = selectRandomWinner();
            require(msg.sender == winner, "Not the selected winner.");

            payout = getContractBalance();
        }

        bettor.claimed = true;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        require(success, "Transfer failed.");

        emit WinningsClaimed(msg.sender, payout);
    }

    /**
     * @dev Selects a random winner among the bettors who bet on the winning outcome.
     * @return winner Address of the selected winner.
     */
    function selectRandomWinner() internal view returns (address winner) {
        address[] storage potentialWinners = bettorsPerOutcome[winningOutcomeIndex];
        require(potentialWinners.length > 0, "No bettors on winning outcome.");

        uint256 randomIndex = uint256(randomNumber) % potentialWinners.length;
        winner = potentialWinners[randomIndex];
    }

    /**
     * @dev Allows bettors to withdraw their bets if the pool is closed but not resolved.
     */
    function withdrawBet() public {
        require(state == PoolState.Closed, "Betting not closed yet.");
        require(!resolved, "Cannot withdraw after resolution.");

        uint256 totalBet = 0;

        for (uint256 i = 0; i < outcomes.length; i++) {
            uint256 betAmount = bettors[msg.sender].bets[i];
            if (betAmount > 0) {
                totalBet += betAmount;
                bettors[msg.sender].bets[i] = 0;
                outcomes[i].totalBets -= betAmount;
            }
        }

        require(totalBet > 0, "No bet to withdraw.");

        (bool success, ) = payable(msg.sender).call{value: totalBet}("");
        require(success, "Transfer failed.");
    }

    /**
     * @dev Returns the list of all prediction outcomes.
     * @return Array of PredictionOutcome structs.
     */
    function getOutcomes()
        public
        view
        returns (PredictionOutcome[] memory)
    {
        return outcomes;
    }

    /**
     * @dev Returns details of a specific outcome.
     * @param _index Index of the outcome.
     * @return name_ Name of the outcome.
     * @return totalBets_ Total amount bet on the outcome.
     * @return initialProbability_ Initial probability of the outcome.
     * @return value_ Numeric value associated with the outcome.
     */
    function getOutcome(uint256 _index)
        public
        view
        returns (
            string memory name_,
            uint256 totalBets_,
            uint256 initialProbability_,
            uint256 value_
        )
    {
        require(_index < outcomes.length, "Outcome does not exist.");
        PredictionOutcome storage outcome = outcomes[_index];
        return (
            outcome.name,
            outcome.totalBets,
            outcome.initialProbability,
            outcome.value
        );
    }

    /**
     * @dev Returns the number of outcomes in the pool.
     * @return Number of prediction outcomes.
     */
    function getNumberOfOutcomes() public view returns (uint256) {
        return outcomes.length;
    }

    /**
     * @dev Returns the bets placed by a specific bettor on all outcomes.
     * @param _bettor Address of the bettor.
     * @return bets Array of bet amounts corresponding to each outcome.
     */
    function getBettorBets(address _bettor)
        public
        view
        returns (uint256[] memory)
    {
        uint256 numOutcomes = outcomes.length;
        uint256[] memory bets = new uint256[](numOutcomes);
        for (uint256 i = 0; i < numOutcomes; i++) {
            bets[i] = bettors[_bettor].bets[i];
        }
        return bets;
    }

    /**
     * @dev Toggles the paused state of the contract.
     */
    function togglePause() public onlyOwner {
        paused = !paused;
    }

    /**
     * @dev Extends the betting deadline by a specified number of days.
     * @param _daysToAdd Number of days to add to the current deadline.
     */
    function extendDeadline(uint256 _daysToAdd)
        public
        onlyOwner
        poolOpen
    {
        deadline += _daysToAdd * 1 days;
    }

    /**
     * @dev Returns the current status of the pool.
     * @return The current PoolState.
     */
    function getPoolStatus() public view returns (PoolState) {
        if (state == PoolState.Open && block.timestamp >= deadline) {
            return PoolState.Closed;
        }
        return state;
    }

    /**
     * @dev Returns the total balance (total bets) held by the contract.
     * @return Contract balance in wei.
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
