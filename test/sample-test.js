const {ethers, network} = require('hardhat');
const {expect} = require('chai');
const BN = require("bn.js")

function getInt(value) {
    return parseInt(value._hex, 16);
}

describe('JoeHatBondingCurve', () => {
    before(async function () {
        this.JoeHatToken = await ethers.getContractFactory('JoeHatToken');
        this.JoeHatBondingCurve = await ethers.getContractFactory('JoeHatBondingCurve');
        this.JoeHatNFT = await ethers.getContractFactory('JoeHatNFT');
        this.signers = await ethers.getSigners();
        this.alice = this.signers[0];
        this.bob = this.signers[1];
        this.carol = this.signers[2];
        this.dave = this.signers[3];
        this.malaury = this.signers[4];
        this.susie = this.signers[5];
        this.owner = this.signers[6];
    });

    beforeEach(async function () {
        this.token = await this.JoeHatToken.deploy();
        await this.token.deployed();

        this.nft = await this.JoeHatNFT.deploy();
        await this.nft.deployed();

        this.hat = await this.JoeHatBondingCurve.deploy(this.nft.address, this.token.address, '30000000000000000000', '15000000000000000000');
        await this.hat.deployed();

        await this.token.transfer(this.hat.address, '150000000000000000000');
        await this.nft.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', this.hat.address);
    });

    it('should have correct totalSupply, reserveHat, reserveAvax, k, _a, _b', async function () {
        const totalSupply = getInt(await this.hat.totalSupply());
        const reserveHat = getInt(await this.hat.reserveHat());
        const reserveAvax = getInt(await this.hat.reserveAvax());
        const k = getInt(await this.hat.k());
        const _a = getInt(await this.hat._a());
        const _b = getInt(await this.hat._b());

        // console.log(totalSupply, reserveHat, reserveAvax, k, _a, _b)

        expect(totalSupply).to.equal(150e18);
        expect(reserveHat).to.equal(150e18);
        expect(reserveAvax).to.equal(90e18);
        expect(k).to.equal(13500e18);
        expect(_a).to.equal(95);
        expect(_b).to.equal(100);
    });

    it('tests front run', async function () {
        const hatAmount = '15000000000000000000';
        const _a = new BN('95');
        const _b = new BN('100');

        const avaxAmount = await this.hat.getAvaxAmountInForExactHatAmountOut(hatAmount);
        await Promise.all([
            this.hat.connect(this.bob).swapExactAvaxForHat(hatAmount, {value: avaxAmount}),
            expect(this.hat.connect(this.alice).swapExactAvaxForHat((new BN(hatAmount)).mul(new BN('99')).div(new BN('100')).toString(),
                {value: avaxAmount})).to.be.revertedWith("Front ran"),
            this.hat.connect(this.malaury).swapExactAvaxForHat((new BN(hatAmount)).mul(new BN('67')).div(new BN('100')).toString(),
                {value: avaxAmount})
        ])

        await this.token.connect(this.bob).approve(this.hat.address, hatAmount);
        await this.hat.connect(this.bob).swapExactHatForAvaxWithFees(hatAmount,
            (new BN(getInt(avaxAmount).toString())).mul(_a).div(_b).toString());
        expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(0);
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(137727272727272730000);


        // const hatAmount = await this.hat.getHatAmountInForExactAvaxAmountOutWithFees('9500000000000000000');
        // await this.hat.connect(this.bob).swapExactHatForAvaxWithFees(hatAmount);
        // expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(0);
        // expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(150000000000000000000);
    });

    after(async function () {
        await network.provider.request({
            method: 'hardhat_reset',
            params: [],
        });
    });
});
