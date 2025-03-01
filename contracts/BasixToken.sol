
/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
pragma solidity 0.6.5;

import "./lib/SafeMathInt.sol";
import "./lib/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BasixToken ERC20 token
 * @dev This is part of an implementation of the BasixToken Ideal Money protocol.
 *      BasixToken is a normal ERC20 token, but its supply can be adjusted by splitting and
 *      combining tokens proportionally across all wallets.
 *
 *      BASIX balances are internally represented with a hidden denomination, 'grains'.
 *      We support splitting the currency in expansion and combining the currency on contraction by
 *      changing the exchange rate between the hidden 'grains' and the public 'fragments'.
 */
contract BasixToken is ERC20, Ownable {
    // PLEASE READ BEFORE CHANGING ANY ACCOUNTING OR MATH
    // Anytime there is division, there is a risk of numerical instability from rounding errors. In
    // order to minimize this risk, we adhere to the following guidelines:
    // 1) The conversion rate adopted is the number of grains that equals 1 fragment.
    //    The inverse rate must not be used--TOTAL_GRAINS is always the numerator and _totalSupply is
    //    always the denominator. (i.e. If you want to convert grains to fragments instead of
    //    multiplying by the inverse rate, you should divide by the normal rate)
    // 2) Grain balances converted into Fragments are always rounded down (truncated).
    //
    // We make the following guarantees:
    // - If address 'A' transfers x Fragments to address 'B'. A's resulting public balance will
    //   be decreased by precisely x Fragments, and B's public balance will be precisely
    //   increased by x Fragments.
    //
    // We do not guarantee that the sum of all balances equals the result of calling totalSupply().
    // This is because, for any conversion function 'f()' that has non-zero rounding error,
    // f(x0) + f(x1) + ... + f(xn) is not always equal to f(x0 + x1 + ... xn).
    using SafeMath for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event LogMonetaryPolicyUpdated(address monetaryPolicy);

    // Used for authentication
    address public monetaryPolicy;

    modifier onlyMonetaryPolicy() {
        require(msg.sender == monetaryPolicy, "Required Monetarypolicy");
        _;
    }

    bool private rebasePausedDeprecated;
    bool private tokenPausedDeprecated;

    modifier validRecipient(address to) {
        require(to != address(0x0), "No valid address");
        require(to != address(this), "No valid address");
        _;
    }

    uint256 private constant DECIMALS = 18;
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 2000000 * uint(10)**DECIMALS;
    uint256 private constant TRANSFER_FEE = 100; // 1%

    // TOTAL_GRAINS is a multiple of INITIAL_FRAGMENTS_SUPPLY so that _grainsPerFragment is an integer.
    // Use the highest value that fits in a uint256 for max granularity.
    uint256 private constant TOTAL_GRAINS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    // MAX_SUPPLY = maximum integer < (sqrt(4*TOTAL_GRAINS + 1) - 1) / 2
    uint256 private constant MAX_SUPPLY = ~uint128(0);  // (2^128) - 1

    uint256 private _totalSupply;
    uint256 private _grainsPerFragment;
    mapping(address => uint256) private _grainBalances;
    mapping(address => bool) _feeWhiteList;

    // This is denominated in Fragments, because the grains-fragments conversion might change before
    // it's fully paid.
    mapping (address => mapping (address => uint256)) private _allowedFragments;

    constructor (
        string memory name_,
        string memory symbol_,
        address owner_,
        address pool_
    ) 
      ERC20(name_, symbol_) public {

        rebasePausedDeprecated = false;
        tokenPausedDeprecated = false;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _grainsPerFragment = TOTAL_GRAINS.div(_totalSupply);

        uint256 poolVal = 200000 * (10 ** DECIMALS);
        uint256 poolGrains = poolVal.mul(_grainsPerFragment);

        _grainBalances[owner_] = TOTAL_GRAINS.sub(poolGrains);
        _grainBalances[pool_] = poolGrains;

        addToWhitelist(owner_);
        addToWhitelist(pool_);

        emit Transfer(address(0x0), owner_, _totalSupply.sub(poolVal));
        emit Transfer(address(0x0), pool_, poolVal);
    }
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function addToWhitelist(address wallet) onlyOwner() public {
        _feeWhiteList[wallet] = true;
    }

    function removeFromWhitelist(address wallet) onlyOwner() public {
        _feeWhiteList[wallet] = false;
    }

    /**
     * @param monetaryPolicy_ The address of the monetary policy contract to use for authentication.
     */
    function setMonetaryPolicy(address monetaryPolicy_)
        public
        onlyOwner
    {
        monetaryPolicy = monetaryPolicy_;
        emit LogMonetaryPolicyUpdated(monetaryPolicy_);
    }

    /**
     * @dev Notifies Fragments contract about a new rebase cycle.
     * @param supplyDelta The number of new fragment tokens to add into circulation via expansion.
     * @return The total number of fragments after the supply adjustment.
     */
    function rebase(uint256 epoch, int256 supplyDelta)
        public
        onlyMonetaryPolicy
        returns (uint256)
    {
        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            _totalSupply = _totalSupply.sub(uint256(supplyDelta.abs()));
        } else {
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _grainsPerFragment = TOTAL_GRAINS.div(_totalSupply);

        // From this point forward, _grainsPerFragment is taken as the source of truth.
        // We recalculate a new _totalSupply to be in agreement with the _grainsPerFragment
        // conversion rate.
        // This means our applied supplyDelta can deviate from the requested supplyDelta,
        // but this deviation is guaranteed to be < (_totalSupply^2)/(TOTAL_GRAINS - _totalSupply).
        //
        // In the case of _totalSupply <= MAX_UINT128 (our current supply cap), this
        // deviation is guaranteed to be < 1, so we can omit this step. If the supply cap is
        // ever increased, it must be re-included.
        // _totalSupply = TOTAL_GRAINS.div(_grainsPerFragment)

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    /**
     * @param who The address to query.
     * @return The balance of the specified address.
     */
    function balanceOf(address who) public view override returns (uint256) {
        return _grainBalances[who].div(_grainsPerFragment);
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @return True on success, false otherwise.
     */
    function transfer(address to, uint256 value)
        public
        override
        validRecipient(to)
        returns (bool)
    {
        if (_feeWhiteList[to] || _feeWhiteList[msg.sender]) {
            uint256 grainValue = value.mul(_grainsPerFragment);

            _grainBalances[msg.sender] = _grainBalances[msg.sender].sub(grainValue);
            _grainBalances[to] = _grainBalances[to].add(grainValue);
            emit Transfer(msg.sender, to, value);
            return true;
        } else {
            uint256 grainValue = value.mul(_grainsPerFragment);
            uint256 grainFee = grainValue.div(10000).mul(TRANSFER_FEE);
            uint256 newGrainsValue = grainValue - grainFee;
            uint256 newValue = newGrainsValue.div(_grainsPerFragment);

            _burn(msg.sender, grainFee);

            _grainBalances[msg.sender] = _grainBalances[msg.sender].sub(newGrainsValue);
            _grainBalances[to] = _grainBalances[to].add(newGrainsValue);
            emit Transfer(msg.sender, to, newValue);
            return true;
        }
    }

    /**
     * @dev Function to check the amount of tokens that an owner has allowed to a spender.
     * @param owner_ The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return The number of tokens still available for the spender.
     */
    function allowance(address owner_, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address you want to send tokens from.
     * @param to The address you want to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transferFrom(address from, address to, uint256 value)
        public
        override
        validRecipient(to)
        returns (bool)
    {
        _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender].sub(value);

        if (_feeWhiteList[from] || _feeWhiteList[to]) {
            uint256 grainValue = value.mul(_grainsPerFragment);

            _grainBalances[from] = _grainBalances[from].sub(grainValue);
            _grainBalances[to] = _grainBalances[to].add(grainValue);
            emit Transfer(from, to, value);

            return true;
        } else {
            uint256 grainValue = value.mul(_grainsPerFragment);
            uint256 grainFee = grainValue.div(10000).mul(TRANSFER_FEE);
            uint256 newGrainsValue = grainValue - grainFee;
            uint256 newValue = newGrainsValue.div(_grainsPerFragment);

            _burn(from, grainFee);

            _grainBalances[from] = _grainBalances[from].sub(newGrainsValue);
            _grainBalances[to] = _grainBalances[to].add(newGrainsValue);
            emit Transfer(from, to, newValue);

            return true;
        }
    }

    function _burn(address account, uint256 grainsAmount) internal override {
        require(account != address(0), "ERC20: burn from the zero address");

        _grainBalances[account] = _grainBalances[account].sub(grainsAmount, "ERC20: burn amount exceeds balance");
        
        uint256 amount = grainsAmount.div(_grainsPerFragment);
        
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of
     * msg.sender. This method is included for ERC20 compatibility.
     * increaseAllowance and decreaseAllowance should be used instead.
     * Changing an allowance with this method brings the risk that someone may transfer both
     * the old and the new allowance - if they are both greater than zero - if a transfer
     * transaction is mined before the later approve() call is mined.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner has allowed to a spender.
     * This method should be used instead of approve() to avoid the double approval vulnerability
     * described above.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] =
            _allowedFragments[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner has allowed to a spender.
     *
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }
}