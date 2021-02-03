pragma solidity 0.6.5;

import "./Interfaces.sol";
import "./UFragmentsPolicy.sol";
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

    UFragmentsPolicy public policy;
    YearnRewardsI public pool;
    ERC20 public basix;
    uint256 public rebaseRequiredSupply;
    address public deployer;
    UniV2PairI public uniSyncs;

    uint256 constant SYNC_GAS = 50000;
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
        address synth_sUSD_,
        uint256 rebaseRequiredSupply_
    ) public {
        policy      = UFragmentsPolicy(policy_);
        pool        = YearnRewardsI(pool_);
        basix       = ERC20(basix_);
        uniSyncs    = genUniAddr(basix_, synth_sUSD_);

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
        require(rewardsDistributed >= rebaseRequiredSupply || block.timestamp >= pool.starttime(), "Rebase not ready"); // TODO: Add + 1 days ???

        policy.rebase();

        // Swiper no swiping.
        // using low level call to prevent reverts on remote error/non-existence
        // address(uniSyncs[i]).call.gas(SYNC_GAS)(uniSyncs[i].sync.selector);
        // address(uniSyncs[i]).call{gas: SYNC_GAS}(
        //     abi.encode(uniSyncs[i].sync.selector)
        // );

        uniSyncs.sync();
    }
}
