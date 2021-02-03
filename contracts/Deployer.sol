pragma solidity 0.6.5;

import './lib/IUniswapV2Pair.sol';
import './lib/IUniswapV2Factory.sol';

contract Deployer {
    constructor(address token0, address token1) public {
        IUniswapV2Pair(IUniswapV2Factory(address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f))
            .createPair(token0, token1));
    }
}
