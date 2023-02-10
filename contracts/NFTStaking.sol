// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title John's NFT Staking Contract
/// @author John Pioc (www.johnpioc.com)
/// @notice This contract can be used to stake ERC721A token standard NFTs

import "erc721a/contracts/IERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

error NFTStaking__ContractNotApproved();
error NFTStaking__StakingNotOpen();

contract NFTStaking is ERC721Holder, Ownable {

    struct Stake {
        uint256 timestamp;
        address owner;
    }

    IERC721A public nftAddress;
    bool public isStakingOpen;

    event NFTStaked(address owner, uint256 tokenId, uint256 timestamp);
    event NFTUnstaked(address owner, uint256 tokenId, uint256 timestamp);

    mapping(uint256 => Stake) public vault;

    constructor(address _nftAddress) {
        nftAddress = IERC721A(_nftAddress);
        isStakingOpen = false;
    }

    /// @notice Function to stake an array of token IDs. Token IDs that don't belong to the caller will not get staked
    /// @param _tokenIds Array of token IDs
    function stakeMany(uint256[] calldata _tokenIds) public {
        if (!isStakingOpen) revert NFTStaking__StakingNotOpen();
        if (!nftAddress.isApprovedForAll(msg.sender, address(this))) revert NFTStaking__ContractNotApproved();

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            if (nftAddress.ownerOf(tokenId) == msg.sender) {
                vault[tokenId] = Stake({
                    timestamp: uint256(block.timestamp),
                    owner: msg.sender
                });

                nftAddress.transferFrom(msg.sender, address(this), tokenId);
                emit NFTStaked(msg.sender, tokenId, block.timestamp);
            }
        }
    }

    /// @notice Function to unstake an array of token IDs. Token IDs that don't belong to the caller will not get unstaked
    /// @param _tokenIds Array of token IDs
    function unstakeMany(uint256[] calldata _tokenIds) public {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            Stake memory stakeDetails = vault[tokenId];
            if (stakeDetails.owner == msg.sender) {
                delete vault[tokenId];
                nftAddress.transferFrom(address(this), msg.sender, tokenId);
                emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
            }
        }
    }

    /// @notice Function to force unstake an array of token IDs. Only callable by owner. Token IDs not originally staked are not touched
    /// @param _tokenIds Array of token IDs
    function forceUnstakeMany(uint256[] calldata _tokenIds) public onlyOwner {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            Stake memory stakeDetails = vault[tokenId];
            if (stakeDetails.timestamp != 0) {
                delete vault[tokenId];
                nftAddress.transferFrom(address(this), stakeDetails.owner, tokenId);
                emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
            }
        }
    }

    /// @notice Function to set the NFT address. Only callable by owner
    /// @param _nftAddress Address of the NFT collection's contract
    function setNftAddress(address _nftAddress) public onlyOwner {
        nftAddress = IERC721A(_nftAddress);
    }

    /// @notice Function to toggle the 'isStakingOpen' variable
    function toggleStakingOpen() public onlyOwner {
        isStakingOpen = !isStakingOpen;
    }
}