/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
pragma solidity 0.6.5;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/Address.sol";
import "./IBasixNFT.sol";

contract BasixNFTSale is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using Address for address payable;

    /* Events */
    event SaleCreated(
        uint256 supply,
        uint256 image,
        uint256 rarity,
        uint256 basixPrice,
        uint256 ethPrice,
        uint256 date
    );
    event TokenBuyed(
        address indexed wallet,
        uint256 tokenId,
        uint256 image,
        uint256 rarity,
        uint256 basixPrice,
        uint256 ethPrice,
        uint256 date
    );

    /* Vars */
    address public basixERC20;
    address public basixERC721;
    address payable public feesReceiver;

    struct Sale {
        uint256 supply;
        uint256 sold;
        uint256 image;
        uint256 rarity;
        uint256 basixPrice;
        uint256 ethPrice;
    }

    // image => rarity => Sale
    mapping (uint256 => mapping(uint256 => Sale)) public salesMap;
    // wallet => image => rarity => true
    mapping (address => mapping(uint256 => mapping(uint256 => bool))) public partitipantMap;

    /* Modifiers */
    modifier saleExists(uint256 _image, uint256 _rarity) {
        require(
            !(salesMap[_image][_rarity].supply == 0),
            "BasixNFTSale: Sale for image and rarity not exists"
        );
        _;
    }
    modifier saleNotExists(uint256 _image, uint256 _rarity) {
        require(
            (salesMap[_image][_rarity].supply == 0),
            "BasixNFTSale: Sale for image and rarity already exists"
        );
        _;
    }
    modifier supplyAvailable(uint256 _image, uint256 _rarity) {
        require(
            (salesMap[_image][_rarity].supply > salesMap[_image][_rarity].sold),
            "BasixNFTSale: All sale supply has been sold"
        );
        _;
    }
    modifier isFirstBuy(address _wallet, uint256 _image, uint256 _rarity) {
        require(
            (partitipantMap[_wallet][_image][_rarity] == false),
            "BasixNFTSale: Address already buyed in this sale"
        );
        _;
    }
    modifier validRarity(uint256 _rarity) {
        require(
            _rarity >= 1 && _rarity <= 5,
            "BasixNFTSale: Rarity must be between 1 and 5"
        );
        _;
    }

    /* Functions */
    constructor(
        address _basixERC20,
        address _basixERC721
    ) public {
        require(address(_basixERC20) != address(0), "BasixNFTSale: Address can't be 0x0 address");
        require(address(_basixERC721) != address(0), "BasixNFTSale: Address can't be 0x0 address");

        basixERC20 = _basixERC20;
        basixERC721 = _basixERC721;
        feesReceiver = msg.sender;
    }

    /**
    * @dev Create a new NFT Sale
    */
    function createSale(
        uint256 _supply,
        uint256 _image,
        uint256 _tokenRarity,
        uint256 _basixPrice,
        uint256 _ethPrice
    )
        public
        onlyOwner()
        saleNotExists(_image, _tokenRarity)
        validRarity(_tokenRarity)
    {
        salesMap[_image][_tokenRarity] = Sale({
            supply: _supply,
            sold: 0,
            image: _image,
            rarity: _tokenRarity,
            basixPrice: _basixPrice,
            ethPrice: _ethPrice
        });

        emit SaleCreated(
            _supply,
            _image,
            _tokenRarity,
            _basixPrice,
            _ethPrice,
            _getTimestamp()
        );
    }

    /**
    * @dev Buy a Basix NFT Token on Sale
    */
    function buy(
        uint256 _image,
        uint256 _tokenRarity
    )
        public
        payable
        saleExists(_image, _tokenRarity)
        supplyAvailable(_image, _tokenRarity)
        isFirstBuy(msg.sender, _image, _tokenRarity)
    {
        uint256 basixAmount = salesMap[_image][_tokenRarity].basixPrice;
        uint256 ethAmount = salesMap[_image][_tokenRarity].ethPrice;

        partitipantMap[msg.sender][_image][_tokenRarity] = true;

        feesReceiver.sendValue(ethAmount);
        _burnBasix(msg.sender, basixAmount);

        salesMap[_image][_tokenRarity].sold += 1;

        uint256 tokenId = IBasixNFT(basixERC721).mintNFT(msg.sender, _image, _tokenRarity);

        emit TokenBuyed(
            msg.sender,
            tokenId,
            _image,
            _tokenRarity,
            basixAmount,
            ethAmount,
            _getTimestamp()
        );
    }
    
    /**
    * @dev Burns Basix tokens.
    */
    function _burnBasix(
        address _wallet,
        uint256 _amount
    ) internal {
        require(IERC20(basixERC20).transferFrom(
            _wallet,
            0x000000000000000000000000000000000000dEaD,
            _amount
        ), "BasixNFTSale: Must approve the ERC20 first");
    }

    /**
    * @dev Sets the address that gets all ETH fees for every buy.
    */
    function setFeesReceiver(address payable _feesReceiver) public onlyOwner() {
        require(address(_feesReceiver) != address(0), "BasixNFTSale: Address can't be 0x0 address");
        feesReceiver = _feesReceiver;
    }

    /**
    * @dev Returns current timestamp.
    */
    function _getTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

}
