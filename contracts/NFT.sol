// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title John's ERC721A Contract
/// @author John Pioc (www.johnpioc.com)
/// @notice This contract can be used to mint ERC721A standard NFTs with industry standard functionality - whitelisted addresses, reveals, NFT metadata, etc.

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

error NFT__CallerIsNotUser();
error NFT__InvalidWhitelistAllocation();
error NFT__MintingTooMany();
error NFT__InsufficientFunds();
error NFT__MintingOverCollectionSize();
error NFT__SaleIsClosed();
error NFT__MintingOverWhitelistAllocation();
error NFT__InvalidProof();

contract NFT is ERC721A, Ownable {

    using Strings for uint256;

    enum SaleState {
        CLOSED,
        WHITELIST,
        PUBLIC
    }

    uint256 public collectionSize = 1000;
    uint256 public publicMintPrice = 0.1 ether;
    uint256 public publicMaxMintAmount = 3;
    uint256 public whitelistAllocation = 500;
    uint256 public whitelistMintPrice = 0.05 ether;
    uint256 public whitelistMaxMintAmount = 1;
    bytes32 public whitelistMerkleRoot;
    string public unrevealedUri = "https://exampleUnrevealedUri.com";
    string public baseUri = "https://exampleUri.com/";
    bool public isRevealed;
    SaleState public saleState;

    /// @notice Modifier to verify that caller doesn't come from a contract
    modifier callerIsUser() {
        if (tx.origin != msg.sender) revert NFT__CallerIsNotUser();
        _;
    }

    constructor() ERC721A ("NFT", "NFT") {
        isRevealed = false;
        saleState = SaleState.CLOSED;
    }

    /// @notice Function to mint NFTs during the public sale
    /// @param _mintAmount Number of NFTs to mint
    function publicMint(uint64 _mintAmount) public payable callerIsUser {
        if (_numberMinted(msg.sender) - _getAux(msg.sender) + _mintAmount > publicMaxMintAmount) revert NFT__MintingTooMany();
        if (totalSupply() + _mintAmount > collectionSize) revert NFT__MintingOverCollectionSize();
        if (saleState != SaleState.PUBLIC) revert NFT__SaleIsClosed();
        if (msg.value < _mintAmount * publicMintPrice) revert NFT__InsufficientFunds();

        _safeMint(msg.sender, _mintAmount);
    }

    /// @notice Function to mint NFTs during the whitelist sale
    /// @param _merkleProof Merkle Proof for caller's address
    /// @param _mintAmount Number of NFTs to mint
    function whitelistMint(bytes32[] calldata _merkleProof, uint64 _mintAmount) public payable callerIsUser {
        if (_getAux(msg.sender) + _mintAmount > whitelistMaxMintAmount) revert NFT__MintingTooMany();
        if (totalSupply() + _mintAmount > whitelistAllocation) revert NFT__MintingOverWhitelistAllocation();
        if (saleState != SaleState.WHITELIST) revert NFT__SaleIsClosed();
        if (msg.value < _mintAmount * whitelistMintPrice) revert NFT__InsufficientFunds();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if(!(MerkleProof.verify(_merkleProof, whitelistMerkleRoot, leaf))) revert NFT__InvalidProof();

        _setAux(msg.sender, _getAux(msg.sender) + _mintAmount);
        _safeMint(msg.sender, _mintAmount);
    }

    /// @notice Sets a new collection size
    /// @dev Only owner can call this function
    /// @param _collectionSize New Collection Size
    function setCollectionSize(uint256 _collectionSize) public onlyOwner {
        collectionSize = _collectionSize;
    }

    /// @notice Sets a new public mint price
    /// @dev Only owner can call this function
    /// @param _publicMintPrice New public mint price
    function setPublicMintPrice(uint256 _publicMintPrice) public onlyOwner {
        publicMintPrice = _publicMintPrice;
    }

    /// @notice Sets a new public max mint amount
    /// @dev Only owner can call this function
    /// @param _publicMaxMintAmount New public max mint amount
    function setPublicMaxMintAmount(uint256 _publicMaxMintAmount) public onlyOwner {
        publicMaxMintAmount = _publicMaxMintAmount;
    }

    /// @notice Sets a new whitelist allocation
    /// @dev Only owner can call this function. New whitelist allocation cannot be greater than collection size
    /// @param _whitelistAllocation New whitelist allocation
    function setWhitelistAllocation(uint256 _whitelistAllocation) public onlyOwner {
        if (_whitelistAllocation > collectionSize) revert NFT__InvalidWhitelistAllocation();
        whitelistAllocation = _whitelistAllocation;
    }

    /// @notice Sets a new whitelist mint price
    /// @dev Only owner can call this function
    /// @param _whitelistMintPrice New whitelist mint price
    function setWhitelistMintPrice(uint256 _whitelistMintPrice) public onlyOwner {
        whitelistMintPrice = _whitelistMintPrice;
    }

    /// @notice Sets a new whitelist max mint amount
    /// @dev Only owner can call this function
    /// @param _whitelistMaxMintAmount New whitelist max mint amount
    function setWhitelistMaxMintAmount(uint256 _whitelistMaxMintAmount) public onlyOwner {
        whitelistMaxMintAmount = _whitelistMaxMintAmount;
    }

    /// @notice Sets a new whitelist merkle root
    /// @dev Only owner can call this function
    /// @param _whitelistMerkleRoot New whitelist merkle root
    function setWhitelistMerkleRoot(bytes32 _whitelistMerkleRoot) public onlyOwner {
        whitelistMerkleRoot = _whitelistMerkleRoot;
    }

    /// @notice Sets a new unrevealed URI
    /// @dev Only owner can call this function
    /// @param _unrevealedUri New unrevealed URI
    function setUnrevealedUri(string memory _unrevealedUri) public onlyOwner {
        unrevealedUri = _unrevealedUri;
    }

    /// @notice Sets a new base URI
    /// @dev Only owner can call this function
    /// @param _baseUri New base URI
    function setBaseUri(string memory _baseUri) public onlyOwner {
        baseUri = _baseUri;
    }

    /// @notice Toggles reveal from false to true, vice versa
    /// @dev Only owner can call this function. Starts at false
    function toggleRevealed() public onlyOwner {
        isRevealed = !isRevealed;
    }

    /// @notice Sets a new sale state
    /// @dev Only owner can call this function. 0 = CLOSED, 1 = WHITELIST, 2 = PUBLIC
    /// @param _saleState new sale state
    function setSaleState(uint256 _saleState) public onlyOwner {
        saleState = SaleState(_saleState);
    }

    /// @notice Generates and returns the token URI for a given token ID
    /// @param _tokenId An NFT's token ID
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        if (!isRevealed) return unrevealedUri;

        return string(abi.encodePacked(baseUri, _tokenId.toString(), ".json"));
    }

    /// @notice Withdraws all ETH from contract to owner's address
    /// @dev Only owner can call this function
    function withdraw() public payable onlyOwner {
        (bool os,) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }
}