/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
pragma solidity 0.6.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BasixTeamLock {

    IERC20 private _basix;
    address private _beneficiary;
    uint256 private _releaseTime;

    constructor (IERC20 basix_, uint256 releaseTime_) public {
        _basix = basix_;
        _beneficiary = msg.sender;
        _releaseTime = releaseTime_;
    }

    /**
     * @return the basix address.
     */
    function basix() public view returns (IERC20) {
        return _basix;
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the time when the Basix tokens are released.
     */
    function releaseTime() public view returns (uint256) {
        return _releaseTime;
    }

    /**
     * Withdraw the team tokens when ready.
     */
    function withdraw() external {
        require(block.timestamp >= releaseTime(), "BasixTeamLock: tokens are still locked");
        uint256 amount = basix().balanceOf(address(this));
        require(amount > 0, "BasixTeamLock: tokens already released");
        basix().transfer(beneficiary(), amount);
    }
}
