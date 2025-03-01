/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
// SPDX-License-Identifier: MIT
pragma solidity 0.6.5;

// Some code reproduced from
// https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2Pair.sol

import './lib/IOracle.sol';
import './lib/FixedPoint.sol';
import './lib/IUniswapV2Pair.sol';
import './lib/UniswapV2Library.sol';
import './lib/IUniswapV2Factory.sol';
import './lib/UniswapV2OracleLibrary.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract OracleSimple {
    using FixedPoint for *;

    uint public PERIOD = 24 hours;

    IUniswapV2Pair immutable pair;
    address public immutable token0;
    address public immutable token1;

    uint    public price0CumulativeLast;
    uint    public price1CumulativeLast;
    uint32  public blockTimestampLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    constructor(address factory, address tokenA, address tokenB) public {
        IUniswapV2Pair _pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB));
        pair = _pair;
        token0 = _pair.token0();
        token1 = _pair.token1();
        price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        // ensure that there's liquidity in the pair
        require(reserve0 != 0 && reserve1 != 0, 'OracleSimple: NO_RESERVES');
    }

    function update() internal {
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // ensure that at least one full period has passed since the last update
        require(timeElapsed >= PERIOD, 'OracleSimple: PERIOD_NOT_ELAPSED');

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
        price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint amountIn) internal view returns (uint amountOut) {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, 'OracleSimple: INVALID_TOKEN');
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }
}

interface BasixTokenI {
    function monetaryPolicy() external view returns (address);
}

contract BasixOracle is Ownable, OracleSimple, IOracle {

    address basix;
    uint256 constant SCALE = 10 ** 18;
    address constant uniFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    constructor(address basix_, address susd_) public OracleSimple(uniFactory, basix_, susd_) {
        PERIOD = 23 hours;
        basix = basix_;
    }

    // this must be called 24h before first rebase to get proper price
    function updateBeforeRebase() public onlyOwner {
        update();
    }

    function getData() override external returns (uint256, bool) {
        require(msg.sender == BasixTokenI(basix).monetaryPolicy());
        update();
        uint256 price = consult(basix, SCALE); // will return 1 BASIX in sUSD

        if (price == 0) {
            return (0, false);
        }

        return (price, true);
    }
}
