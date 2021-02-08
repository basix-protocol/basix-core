/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
pragma solidity 0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract BasixPrivateSale is ReentrancyGuard, Ownable {

    using SafeMath for uint256;
    using Address for address payable;

    mapping(address => uint256) participants;
    mapping(address => uint256) public claimableTokens;

    // BASX per ETH price
    uint256 buyPrice;
    uint256 minimalGoal;
    uint256 hardCap;

    IERC20 crowdsaleToken;

    uint256 tokenDecimals = 18;

    event SellToken(address recepient, uint tokensSold, uint value);

    address payable fundingAddress;
    uint256 public totalCollected;
    uint256 totalSold;
    bool claimEnabled = false;
    uint256 claimWaitTime = 60 days;
    uint256 start;


    /**
    30000000000000000003 BASX for sale
    30000000003000000000
    Buy price: 333333333333333 wei | 0,0003333333333 eth
    */
    constructor(
        IERC20 _token,
        address payable _fundingAddress
    ) public {
        minimalGoal = 50000000000000000000;
        hardCap = 100000000000000000000;
        buyPrice = 333333333333333;
        crowdsaleToken = _token;
        fundingAddress = _fundingAddress;
        start = getTime();
    }

    function getToken()
    external
    view
    returns(address)
    {
        return address(crowdsaleToken);
    }

    function getClaimableTokens(address wallet)
    external 
    view
    returns(uint256)
    {
      return claimableTokens[wallet];
    }

    receive() external payable {
        require(msg.value >= 100000000000000000, "Min 0.1 ETH");
        sell(msg.sender, msg.value);
    }

    // For users to claim their tokens after a successful tge
    function claim() external 
      nonReentrant 
    returns (uint256) {
        require(canClaim(), "Claim is not yet possible");
        uint256 amount = claimableTokens[msg.sender];
        claimableTokens[msg.sender] = 0;
        require(crowdsaleToken.transfer(msg.sender, amount), "Error transfering");
        return amount;
    }

    function canClaim() public view returns (bool) {
      return claimEnabled || block.timestamp > (start + claimWaitTime);
    }

    function sell(address payable _recepient, uint256 _value) internal
        nonReentrant
        whenCrowdsaleAlive()
    {
        uint256 newTotalCollected = totalCollected.add(_value);

        if (hardCap < newTotalCollected) {
            // Refund anything above the hard cap
            uint256 refund = newTotalCollected.sub(hardCap);
            uint256 diff = _value.sub(refund);
            _recepient.sendValue(refund);
            _value = diff;
            newTotalCollected = totalCollected.add(_value);
        }

        // Token amount per price
        uint256 tokensSold = (_value).div(buyPrice).mul(10 ** tokenDecimals);


        // Set how much tokens the user can claim
        claimableTokens[_recepient] = claimableTokens[_recepient].add(tokensSold);

        emit SellToken(_recepient, tokensSold, _value);

        // Save participants
        participants[_recepient] = participants[_recepient].add(_value);

        fundingAddress.sendValue(_value);

        // Update total ETH
        totalCollected = totalCollected.add(_value);

        // Update tokens sold
        totalSold = totalSold.add(tokensSold);
    }

  function totalTokensNeeded() external view returns (uint256) {
    return hardCap.div(buyPrice).mul(10 ** tokenDecimals);
  }

  function enableClaim()
    external
    onlyOwner()
  {
        claimEnabled = true;
  }

  function returnUnsold()
    external
    nonReentrant
    onlyOwner()
  {
    crowdsaleToken.transfer(fundingAddress, crowdsaleToken.balanceOf(address(this)));
  }

  function getTime()
    public
    view
    returns(uint256)
  {
    return block.timestamp;
  }

  function isActive()
    public
    view
    returns(bool)
  {
    return (
      totalCollected < hardCap
    );
  }

  function isSuccessful()
    public
    view
    returns(bool)
  {
    return (
      totalCollected >= hardCap || totalCollected >= minimalGoal
    );
  }

  modifier whenCrowdsaleAlive() {
    require(isActive());
    _;
  }

}