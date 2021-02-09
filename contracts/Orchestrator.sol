/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
pragma solidity 0.6.5;

import "./Interfaces.sol";
import "./BasixProtocol.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Orchestrator
 * @notice The orchestrator is the main entry point for rebase operations. It coordinates the policy
 * actions with external consumers.
 */
contract Orchestrator is Ownable {
    using SafeMath for uint256;

    struct Transaction {
        bool enabled;
        address destination;
        bytes data;
    }

    event TransactionFailed(address indexed destination, uint index, bytes data);

    // Stable ordering is not guaranteed.
    Transaction[] public transactions;

    ERC20 public basix;
    address public deployer;
    YearnRewardsI public pool;
    UniV2PairI public uniSyncs;
    BasixProtocol public policy;
    uint256 public rebaseRequiredSupply;

    address constant uniFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    // https://uniswap.org/docs/v2/smart-contract-integration/getting-pair-addresses/
    function genUniAddr(address left, address right) internal pure returns (UniV2PairI) {
        address first = left < right ? left : right;
        address second = left < right ? right : left;
        address pair = address(uint(keccak256(abi.encodePacked(
          hex'ff',
          uniFactory,
          keccak256(abi.encodePacked(first, second)),
          hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'
        ))));
        return UniV2PairI(pair);
    }

    constructor (
        address policy_,
        address pool_,
        address basix_,
        address sUSD_,
        uint256 rebaseRequiredSupply_
    ) public {
        policy      = BasixProtocol(policy_);
        pool        = YearnRewardsI(pool_);
        basix       = ERC20(basix_);
        uniSyncs    = genUniAddr(basix_, sUSD_);

        rebaseRequiredSupply = rebaseRequiredSupply_;
    }

    /**
     * @notice Main entry point to initiate a rebase operation.
     *         The Orchestrator calls rebase on the policy and notifies downstream applications.
     *         Contracts are guarded from calling, to avoid flash loan attacks on liquidity
     *         providers.
     *         If a transaction in the transaction list reverts, it is swallowed and the remaining
     *         transactions are executed.
     */
    function rebase()
        external
    {
        // wait for `rebaseRequiredSupply` token supply to be rewarded until rebase is possible
        // timeout after 4 weeks if people don't claim rewards so it's not stuck
        uint256 rewardsDistributed = pool.totalRewards();
        require(rewardsDistributed >= rebaseRequiredSupply || block.timestamp >= pool.starttime() + 1 days, "Rebase not ready");

        policy.rebase();

        uniSyncs.sync();
    }
}
