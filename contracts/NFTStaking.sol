// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "erc721a/contracts/IERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

error NFTStaking__ContractNotApproved();
error NFTStaking__TokenAlreadyStaked();
error NFTStaking__TransferFailed();
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

    function setNftAddress(address _nftAddress) public onlyOwner {
        nftAddress = IERC721A(_nftAddress);
    }

    function toggleStakingOpen() public onlyOwner {
        isStakingOpen = !isStakingOpen;
    }
}