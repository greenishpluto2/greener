// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {PredictionPoolOracle} from "./PredictionPoolOracle.sol";

/**
 * @title PredictionPoolOracleFactory
 * @dev Factory contract to create and manage PredictionPoolOracle contracts.
 *      Allows users to create their own prediction pools.
 */
contract PredictionPoolOracleFactory {
    address public owner;   // Owner of the factory contract
    bool public paused;     // Indicates if the factory is paused

    /**
     * @dev Structure representing a prediction pool created by a user.
     * @param poolAddress Address of the deployed PredictionPoolOracle contract.
     * @param owner Address of the pool creator.
     * @param name Name of the prediction pool.
     * @param creationTime Timestamp when the pool was created.
     */
    struct Pool {
        address poolAddress;
        address owner;
        string name;
        uint256 creationTime;
    }

    Pool[] public pools;                             // Array of all created pools
    mapping(address => Pool[]) public userPools;     // Mapping of user addresses to their pools

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner.");
        _;
    }

    modifier notPaused() {
        require(!paused, "Factory is paused");
        _;
    }

    /**
     * @dev Constructor that sets the factory owner.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Creates a new PredictionPoolOracle contract.
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
     * @return poolAddress Address of the newly created PredictionPoolOracle contract.
     */
    function createPool(
        string memory _name,
        string memory _description,
        uint256 _maxLimit,
        uint256 _durationInDays,
        PredictionPoolOracle.WinnerType _winnerType,
        PredictionPoolOracle.SettlementType _settlementType,
        address _entropyAddress,
        address _providerAddress,
        address _pythAddress,
        bytes32 _pythPriceFeedId,
        address _chronicleAddress
    ) external notPaused returns (address poolAddress) {
        // Deploy a new PredictionPoolOracle contract
        PredictionPoolOracle newPool = new PredictionPoolOracle(
            msg.sender,
            _name,
            _description,
            _maxLimit,
            _durationInDays,
            _winnerType,
            _settlementType,
            _entropyAddress,
            _providerAddress,
            _pythAddress,
            _pythPriceFeedId,
            _chronicleAddress
        );
        poolAddress = address(newPool);

        // Store the new pool information
        Pool memory pool = Pool({
            poolAddress: poolAddress,
            owner: msg.sender,
            name: _name,
            creationTime: block.timestamp
        });

        pools.push(pool);
        userPools[msg.sender].push(pool);
    }

    /**
     * @dev Returns the list of pools created by a specific user.
     * @param _user Address of the user.
     * @return Array of Pool structs.
     */
    function getUserPools(address _user) external view returns (Pool[] memory) {
        return userPools[_user];
    }

    /**
     * @dev Returns the list of all pools created.
     * @return Array of Pool structs.
     */
    function getAllPools() external view returns (Pool[] memory) {
        return pools;
    }

    /**
     * @dev Toggles the paused state of the factory.
     */
    function togglePause() external onlyOwner {
        paused = !paused;
    }
}