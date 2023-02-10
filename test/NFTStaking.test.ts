import { ethers } from 'hardhat';
import { expect, assert } from 'chai';
import { NFT, NFT__factory, NFTStaking, NFTStaking__factory } from '../typechain-types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe("NFT Staking Contract Unit Tests", () => {
    let nftContract: NFT;
    let stakingContract: NFTStaking;
    let accounts: SignerWithAddress[];
    let account1NftContract: NFT;
    let account1StakingContract: NFTStaking;
    let account2NftContract: NFT;
    let account2StakingContract: NFTStaking;
    let account3NftContract: NFT;
    let account3StakingContract: NFTStaking;
    let attackerStakingContract: NFTStaking;

    beforeEach(async () => {
        const nftContractFactory: NFT__factory = await ethers.getContractFactory("NFT");
        nftContract = await nftContractFactory.deploy();

        const stakingContractFactory: NFTStaking__factory = await ethers.getContractFactory("NFTStaking");
        stakingContract = await stakingContractFactory.deploy(nftContract.address);

        await nftContract.setSaleState(2);

        accounts = await ethers.getSigners();

        account1NftContract = await nftContract.connect(accounts[1]);
        account1StakingContract = await stakingContract.connect(accounts[1]);
        await account1NftContract.publicMint(3, { value: ethers.utils.parseEther("0.3") });
        
        account2NftContract = await nftContract.connect(accounts[2]);
        account2StakingContract = await stakingContract.connect(accounts[2]);
        await account2NftContract.publicMint(3, { value: ethers.utils.parseEther("0.3") });

        account3NftContract = await nftContract.connect(accounts[3]);
        account3StakingContract = await stakingContract.connect(accounts[3]);
        await account3NftContract.publicMint(3, { value: ethers.utils.parseEther("0.3") });

        attackerStakingContract = await stakingContract.connect(accounts[10]);
    });

    describe("Intiial State", () => {
        it("NFT Address should be the address of the NFT Contract", async () => {
            const currentValue: string = await stakingContract.nftAddress();
            const expectedValue: string = nftContract.address;
            assert.equal(currentValue, expectedValue);
        })

        it("Staking should not be open", async () => {
            const currentValue: boolean = await stakingContract.isStakingOpen();
            const expectedValue: boolean = false;
            assert.equal(currentValue, expectedValue);
        })
    });

    describe("'setNftAddress()' Function", () => {
        it("Should revert if called by non owner", async () => {
            const mockAddress = "0xb5E8683Aa524069C5714Fc2D8c3e64F78f2862fb"
            await expect(attackerStakingContract.setNftAddress(mockAddress)).to.be.revertedWith("Ownable: caller is not the owner");
        })

        it("After providing argument: 0xb5E8683Aa524069C5714Fc2D8c3e64F78f2862fb, the nft address should be that", async () => {
            const mockAddress = "0xb5E8683Aa524069C5714Fc2D8c3e64F78f2862fb";
            await stakingContract.setNftAddress(mockAddress);

            const currentValue = await stakingContract.nftAddress();
            assert.equal(currentValue, mockAddress);
        })
    })

    describe("'toggleStakingOpen()' Function", () => {
        it("Should revert if called by non owner", async () => {
            await expect(attackerStakingContract.toggleStakingOpen()).to.be.revertedWith("Ownable: caller is not the owner");
        })

        it("After calling function once, staking should be open", async () => {
            await stakingContract.toggleStakingOpen();

            const currentValue: boolean = await stakingContract.isStakingOpen();
            const expectedValue: boolean = true;
            assert.equal(currentValue, expectedValue);
        })
    })

    describe("'stakeMany()' Function", () => {
        it("Should revert if staking is not open", async () => {
            const tokenIds: number[] = [1,2,3];
            await expect(account1StakingContract.stakeMany(tokenIds)).to.be.revertedWith("NFTStaking__StakingNotOpen");
        })

        it("Should revert if caller hasn't approved the staking contract", async () => {
            await stakingContract.toggleStakingOpen();

            const tokenIds: number[] = [1,2,3];
            await expect(account1StakingContract.stakeMany(tokenIds)).to.be.revertedWith("NFTStaking__ContractNotApproved")
        })

        it("Should not stake any token Ids that the caller doesn't own", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [4,5,6];
            await account1StakingContract.stakeMany(tokenIds);

            const expectedTimestampValue: number = 0;
            const expectedOwnerValue: string = "0x0000000000000000000000000000000000000000";

            const tokenId4StakeDetails = await stakingContract.vault(4);
            assert.equal(parseInt(tokenId4StakeDetails[0].toString()), expectedTimestampValue);
            assert.equal(tokenId4StakeDetails[1], expectedOwnerValue)

            const tokenId5StakeDetails = await stakingContract.vault(5);
            assert.equal(parseInt(tokenId5StakeDetails[0].toString()), expectedTimestampValue);
            assert.equal(tokenId5StakeDetails[1], expectedOwnerValue)

            const tokenId6StakeDetails = await stakingContract.vault(6);
            assert.equal(parseInt(tokenId6StakeDetails[0].toString()), expectedTimestampValue);
            assert.equal(tokenId6StakeDetails[1], expectedOwnerValue)
        })

        it("When account 1 stakes token IDs 1,2 & 3, vault details should be updated to current timestamp and account 1's address", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1,2,3];
            await account1StakingContract.stakeMany(tokenIds);

            const blockNumber: number = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);
            const timestamp: number = block.timestamp;

            const tokenId1StakeDetails = await stakingContract.vault(1);
            assert.equal(parseInt(tokenId1StakeDetails[0].toString()), timestamp);
            assert.equal(tokenId1StakeDetails[1], accounts[1].address);

            const tokenId2StakeDetails = await stakingContract.vault(2);
            assert.equal(parseInt(tokenId2StakeDetails[0].toString()), timestamp);
            assert.equal(tokenId2StakeDetails[1], accounts[1].address);

            const tokenId3StakeDetails = await stakingContract.vault(3);
            assert.equal(parseInt(tokenId3StakeDetails[0].toString()), timestamp);
            assert.equal(tokenId3StakeDetails[1], accounts[1].address);
        });

        it("When account 1 staked token IDs 1,2 & 3, staking contract should own those NFTs", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1,2,3];
            await account1StakingContract.stakeMany(tokenIds);

            const expectedValue: string = stakingContract.address;

            const tokenId1Owner = await nftContract.ownerOf(1);
            assert.equal(tokenId1Owner, expectedValue);

            const tokenId2Owner = await nftContract.ownerOf(2);
            assert.equal(tokenId2Owner, expectedValue);

            const tokenId3Owner = await nftContract.ownerOf(3);
            assert.equal(tokenId3Owner, expectedValue);
        })

        it("When account 1 stakes token ID 1, it should emit the NFTStaked event with the accounts address, token ID 1, the the current timestamp", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1];
            const tx = await account1StakingContract.stakeMany(tokenIds);

            const blockNumber: number = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);
            const timestamp: number = block.timestamp;

            await expect(tx).to.emit(stakingContract, "NFTStaked").withArgs(accounts[1].address, 1, timestamp);
        })
    })

    describe("'unstakeMany()' Function", () => {
        it("Shouldn't unstake token IDs when they don't belong to the caller", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1];
            await account1StakingContract.stakeMany(tokenIds);

            const blockNumber: number = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);
            const timestamp: number = block.timestamp;

            await account2StakingContract.unstakeMany(tokenIds);

            const stakeDetails = await stakingContract.vault(1);
            const expectedTimeStampValue = timestamp;
            const expectedOwnerValue = accounts[1].address;

            assert.equal(parseInt(stakeDetails[0].toString()), expectedTimeStampValue);
            assert.equal(stakeDetails[1], expectedOwnerValue)
        })

        it("When account 1 unstakes token ID 1, token ID 1 vault details should have a timestamp of zero and owner should be zero address", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1];
            await account1StakingContract.stakeMany(tokenIds);
            await account1StakingContract.unstakeMany(tokenIds);

            const stakeDetails = await stakingContract.vault(1);
            const expectedTimeStampValue = 0;
            const expectedOwnerValue = "0x0000000000000000000000000000000000000000";

            assert.equal(parseInt(stakeDetails[0].toString()), expectedTimeStampValue);
            assert.equal(stakeDetails[1], expectedOwnerValue)
        })

        it("When account 1 unstaked token ID 1, the NFT should be returned back", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1];
            await account1StakingContract.stakeMany(tokenIds);
            await account1StakingContract.unstakeMany(tokenIds);

            const currentValue = await nftContract.ownerOf(1);
            const expectedValue = accounts[1].address;
            assert.equal(currentValue, expectedValue);
        })

        it("When account 1 unstakes token ID 1, it should emit the NFTUnstaked event with the account's address, token ID 1, and the current timestamp", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1];
            await account1StakingContract.stakeMany(tokenIds);

            const tx = await account1StakingContract.unstakeMany(tokenIds);

            const blockNumber: number = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);
            const timestamp: number = block.timestamp;

            await expect(tx).to.emit(stakingContract, "NFTUnstaked").withArgs(accounts[1].address, 1, timestamp);
        })
    })

    describe("'forceUnstakeMany()' Function", async () => {
        it("Function should revert if caller is not the owner", async () => {
            const tokenIds = [1];
            await expect(attackerStakingContract.forceUnstakeMany(tokenIds)).to.be.revertedWith("Ownable: caller is not the owner");
        })

        it("No events should be emitted if the token IDs provided are not staked", async () => {
            const tokenIds = [1,2,3];
            const tx = await stakingContract.forceUnstakeMany(tokenIds);
            const txReceipt = await tx.wait();

            const currentValue: number = txReceipt.logs.length;
            const expectedValue = 0;
            assert.equal(currentValue, expectedValue);
        })

        it("After force unstaking token ID 1, vault details for that token should have a timestamp of zero and owner should be zero address", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1];
            await account1StakingContract.stakeMany(tokenIds);
            await stakingContract.forceUnstakeMany(tokenIds);

            const stakeDetails = await stakingContract.vault(1);
            const expectedTimeStampValue = 0;
            const expectedOwnerValue = "0x0000000000000000000000000000000000000000";

            assert.equal(parseInt(stakeDetails[0].toString()), expectedTimeStampValue);
            assert.equal(stakeDetails[1], expectedOwnerValue)
        })

        it("After force unstaking token ID 1, NFT should return back to original owner", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1];
            await account1StakingContract.stakeMany(tokenIds);
            await stakingContract.forceUnstakeMany(tokenIds);

            const currentValue = await nftContract.ownerOf(1);
            const expectedValue = accounts[1].address;
            assert.equal(currentValue, expectedValue);
        })

        it("When token ID 1 is force unstaked, it should emit the NFTUnstaked event with the owner's address, token ID 1, and the current timestamp", async () => {
            await stakingContract.toggleStakingOpen();
            await account1NftContract.setApprovalForAll(stakingContract.address, true);
            
            const tokenIds: number[] = [1];
            await account1StakingContract.stakeMany(tokenIds);

            const tx = await stakingContract.forceUnstakeMany(tokenIds);

            const blockNumber: number = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);
            const timestamp: number = block.timestamp;

            await expect(tx).to.emit(stakingContract, "NFTUnstaked").withArgs(accounts[0].address, 1, timestamp);
        })
    })
})