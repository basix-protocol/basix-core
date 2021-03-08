/*
     ___    _____  ___    _  _    _ 
    (  _`\ (  _  )(  _`\ (_)( )  ( )
    | (_) )| (_) || (_(_)| |`\`\/'/'
    |  _ <'|  _  |`\__ \ | |  >  <  
    | (_) )| | | |( )_) || | /'/\`\ 
    (____/'(_) (_)`\____)(_)(_)  (_)
*/
pragma solidity 0.6.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BasixNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping (uint256 => uint256) private _tokenImages;
    mapping (uint256 => uint256) private _tokenRarities;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) public ERC721(name, symbol) {
        _setBaseURI(baseURI);
    }

    /**
    * @dev Mints a new Basix NFT for a wallet.
    */
    function mintNFT(
        address wallet,
        uint256 tokenImage,
        uint256 tokenRarity
    )
        public
        onlyOwner()
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(wallet, newItemId);
        _setTokenImage(newItemId, tokenImage);
        _setTokenRarity(newItemId, tokenRarity);

        return newItemId;
    }

    function _setTokenImage(uint256 tokenId, uint256 _tokenImage) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: Image set of nonexistent token");
        _tokenImages[tokenId] = _tokenImage;
    }

    function _setTokenRarity(uint256 tokenId, uint256 _tokenRarity) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: Rarity set of nonexistent token");
        _tokenRarities[tokenId] = _tokenRarity;
    }

    function tokenImage(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "ERC721Metadata: Image query for nonexistent token");
        return _tokenImages[tokenId];
    }

    function tokenRarity(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "ERC721Metadata: Rarity query for nonexistent token");
        return _tokenRarities[tokenId];
    }
}