/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
pragma solidity 0.6.5;

interface YearnRewardsI {
    function starttime() external returns (uint256);
    function totalRewards() external returns (uint256);
    function y() external returns (address);
    function yfi() external returns (address);
    function balanceOf(address _) external returns(uint256);
    function earned(address _) external returns(uint256);
}

interface UniV2PairI {
    function sync() external;
}

interface ERC20MigratorI {
    function totalMigrated() external returns (uint256);
}
