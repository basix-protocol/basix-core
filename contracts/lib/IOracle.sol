pragma solidity 0.6.5;

interface IOracle {
    function getData() external returns (uint256, bool);
}