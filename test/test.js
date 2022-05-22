var NFTTokenContract = artifacts.require('./MyERC721Token.sol');

const nftId1 = 11111;
const nftId2 = 22222;

contract('NFTTokenContract', async (accounts) => {
    let contractInstance, owner, alice, bob;



    it('Mints an NFT', async () => {
        contractInstance = await NFTTokenContract.deployed();
        [owner, alice, bob] = accounts;

        await contractInstance._mint(alice, nftId1, { from: owner });
        const balanceOfAlice = await contractInstance.balanceOf(alice)
        assert.equal(balanceOfAlice, 1, 'Alice received the minted NFT');
    })

    it('Balances of other accounts are correct', async () => {
        assert.equal(await contractInstance.balanceOf(owner), 0);
        assert.equal(await contractInstance.balanceOf(bob), 0);
    })

    it('Errors when trying to mint same NFT twice', async () => {
        try {
            await contractInstance._mint(alice, nftId1, { from: owner });
        } catch (error) {
            assert(error.message.indexOf('revert NFT token already exists') > -1);
        }
    })

    it('Contract is pausable', async () => {
        await contractInstance.pause();
        try {
            await contractInstance._mint(bob, nftId2, { from: owner });
        } catch (error) {
            assert.equal(true, await contractInstance.paused(), "Contract is in paused state");
            assert(error.message.indexOf("revert Contract is paused") > -1);
        }
    })

    it('Contract is unpausable', async () => {
        await contractInstance.unpause();
        await contractInstance._mint(bob, nftId2, { from: owner });
        const balanceOfBob = await contractInstance.balanceOf(bob);
        assert.equal(false, await contractInstance.paused(), "Contract is in unpaused state");
        assert.equal(balanceOfBob, 1, 'Bob received the minted NFT');
    })
})