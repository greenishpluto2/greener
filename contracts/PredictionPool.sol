// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title PredictionPool
 * @dev A contract that allows users to bet on different outcomes of a prediction event.
 *      The probabilities of outcomes adjust dynamically based on the amounts bet on each outcome.
 *      The contract owner can resolve the pool by declaring a winning outcome.
 */
contract PredictionPool {
    // Basic pool information
    string public name;             // Name of the prediction pool
    string public description;      // Description of the prediction pool
    uint256 public maxLimit;        // Optional maximum limit for total bets (0 for no limit)
    uint256 public deadline;        // Betting deadline timestamp
    address public owner;           // Owner of the prediction pool
    bool public paused;             // Indicates if the contract is paused
    bool public resolved;           // Indicates if the pool has been resolved
    uint256 public winningOutcomeIndex; // Index of the winning outcome

    // Possible states of the prediction pool
    enum PoolState { Open, Closed, Resolved }
    PoolState public state;         // Current state of the pool

    /**
     * @dev Structure representing each prediction outcome.
     * @param name Name of the outcome.
     * @param totalBets Total amount bet on this outcome.
     * @param initialProbability Initial probability set by the pool creator (in basis points, 0 to 10000).
     */
    struct PredictionOutcome {
        string name;
        uint256 totalBets;
        uint256 initialProbability; // In basis points (0 to 10000)
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

    PredictionOutcome[] public outcomes;            // Array of prediction outcomes
    mapping(address => Bettor) public bettors;      // Mapping of bettors' addresses to their bets

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

    /**
     * @dev Constructor to initialize the prediction pool.
     * @param _owner Address of the pool owner.
     * @param _name Name of the prediction pool.
     * @param _description Description of the prediction pool.
     * @param _maxLimit Maximum total bets allowed (0 for no limit).
     * @param _durationInDays Duration of the betting period in days.
     */
    constructor(
        address _owner,
        string memory _name,
        string memory _description,
        uint256 _maxLimit,
        uint256 _durationInDays
    ) {
        name = _name;
        description = _description;
        maxLimit = _maxLimit;
        deadline = block.timestamp + (_durationInDays * 1 days);
        owner = _owner;
        state = PoolState.Open;
    }

    /**
     * @dev Adds a new prediction outcome to the pool.
     * @param _name Name of the prediction outcome.
     * @param _initialProbability Initial probability in basis points (0 to 10000).
     */
    function addOutcome(
        string memory _name,
        uint256 _initialProbability
    ) public onlyOwner {
        require(
            _initialProbability >= 0 && _initialProbability <= 10000,
            "Probability must be between 0 and 10000."
        );
        outcomes.push(PredictionOutcome(_name, 0, _initialProbability));
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

        bettors[msg.sender].bets[_outcomeIndex] += msg.value;
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
     * @dev Resolves the pool by declaring a winning outcome.
     * @param _winningOutcomeIndex Index of the winning outcome.
     */
    function resolve(uint256 _winningOutcomeIndex) public onlyOwner {
        require(state == PoolState.Closed, "Betting not closed yet.");
        require(!resolved, "Outcome already resolved.");
        require(
            _winningOutcomeIndex < outcomes.length,
            "Invalid outcome index."
        );
        winningOutcomeIndex = _winningOutcomeIndex;
        state = PoolState.Resolved;
        resolved = true;

        emit OutcomeResolved(_winningOutcomeIndex);
    }

    /**
     * @dev Allows bettors who bet on the winning outcome to claim their winnings.
     */
    function claimWinnings() public {
        require(state == PoolState.Resolved, "Outcome not resolved yet.");
        require(!bettors[msg.sender].claimed, "Winnings already claimed.");

        uint256 winningBet = bettors[msg.sender].bets[winningOutcomeIndex];
        require(winningBet > 0, "No winning bet to claim.");

        uint256 totalWinningBets = outcomes[winningOutcomeIndex].totalBets;
        uint256 totalPoolBets = getContractBalance();

        uint256 payout = (winningBet * totalPoolBets) / totalWinningBets;
        bettors[msg.sender].claimed = true;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        require(success, "Transfer failed.");

        emit WinningsClaimed(msg.sender, payout);
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
     */
    function getOutcome(uint256 _index)
        public
        view
        returns (
            string memory name_,
            uint256 totalBets_,
            uint256 initialProbability_
        )
    {
        require(_index < outcomes.length, "Outcome does not exist.");
        PredictionOutcome storage outcome = outcomes[_index];
        return (
            outcome.name,
            outcome.totalBets,
            outcome.initialProbability
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
