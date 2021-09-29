const {ethers, network} = require('hardhat');
const {expect} = require('chai');
const BN = require('bn.js')

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
        this.owner = this.signers[5];
        this.givenToPeople = this.signers[6];
    });

    beforeEach(async function () {
        this.token = await this.JoeHatToken.deploy();
        await this.token.deployed();

        this.nft = await this.JoeHatNFT.deploy();
        await this.nft.deployed();

        this.hat = await this.JoeHatBondingCurve.deploy(this.nft.address, this.token.address, '20000000000000000000', '5000000000000000000');
        await this.hat.deployed();

        await this.hat.transferOwnership(this.owner.address)
        await this.token.transfer(this.owner.address, '20000000000000000000')
        await this.token.transfer(this.givenToPeople.address, '130000000000000000000')

        await this.token.connect(this.owner).approve(this.hat.address, '20000000000000000000');
        await this.hat.connect(this.owner).seedContract({value: '86666666666666666667'});

        await this.nft.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', this.hat.address);
    });

    it('should have correct totalSupply, reserveHat, reserveAvax, k, _a, _b', async function () {
        const totalSupply = (await this.hat.totalSupply()).toString();
        const reserveHat = (await this.hat.getReserveHat()).toString();
        const reserveAvax = (await this.hat.getReserveAvax()).toString();
        const k = (await this.hat.k()).toString();
        const _a = (await this.hat._a()).toString();
        const _b = (await this.hat._b()).toString();

        expect(totalSupply).to.equal('150000000000000000000');
        expect(reserveHat).to.equal('20000000000000000000');
        expect(reserveAvax).to.equal('100000000000000000000');
        expect(k).to.equal('2000000000000000000000');
        expect(_a).to.equal('95');
        expect(_b).to.equal('100');
    });

    it('tests front run and withdraw function', async function () {
        const hatAmount = '10000000000000000000';
        const _a = new BN('95');
        const _b = new BN('100');

        const avaxAmount = await this.hat.getAvaxAmountInForExactHatAmountOut(hatAmount);

        await Promise.all([
            this.hat.connect(this.bob).swapExactAvaxForHat(hatAmount, {value: avaxAmount}),
            expect(this.hat.connect(this.alice).swapExactAvaxForHat((new BN(hatAmount)).mul(new BN('99')).div(new BN('100')).toString(),
                {value: avaxAmount})).to.be.revertedWith('Front ran'),
            this.hat.connect(this.malaury).swapExactAvaxForHat((new BN(hatAmount)).mul(new BN('1')).div(new BN('100')).toString(),
                {value: avaxAmount}),

            this.token.connect(this.bob).approve(this.hat.address, hatAmount)
        ])

        await this.hat.connect(this.bob).swapExactHatForAvaxWithFees(hatAmount,
            (new BN((avaxAmount).toString())).mul(_a).div(_b).toString());

        const results = await Promise.all([
            this.hat.balanceOf(this.bob.address),
            this.hat.balanceOf(this.hat.address),
        ]);

        expect(results[0].toString()).to.equal('0');
        expect(results[1].toString()).to.equal('16666666666666666666');

        const prov = ethers.provider;
        const balance = await prov.getBalance(this.hat.address)

        await Promise.all([
            expect(this.hat.connect(this.bob).withdrawTeamBalance()).to.be.revertedWith(
                'Ownable: caller is not the owner'),
            this.hat.balanceOf(this.hat.address),
            this.hat.connect(this.owner).withdrawTeamBalance()
        ]);
        expect(balance).to.be.above(await prov.getBalance(this.hat.address))
    });

    it('should buy all the stock', async function () {
        // buys 19 hats
        const avaxAmount = await this.hat.getAvaxAmountInForExactHatAmountOut('19000000000000000000')
        await this.hat.connect(this.bob).swapExactAvaxForHat('19000000000000000000', {value: avaxAmount})
        expect((await this.hat.balanceOf(this.bob.address)).toString()).to.equal('19000000000000000000')
        expect((await this.hat.balanceOf(this.hat.address)).toString()).to.equal('1000000000000000000')


        // buys the last hat
        const avaxAmount2 = await this.hat.getAvaxAmountInForExactHatAmountOut('1000000000000000000')
        await this.hat.connect(this.alice).swapExactAvaxForHat('1000000000000000000', {value: avaxAmount2})
        expect((await this.hat.balanceOf(this.alice.address)).toString()).to.equal('1000000000000000000')
        expect((await this.hat.balanceOf(this.hat.address)).toString()).to.equal('0')

        // sells 1.5 hats
        await expect(this.hat.connect(this.alice).swapExactHatForAvaxWithFees('1', '0'))
            .to.be.revertedWith('ERC20: transfer amount exceeds allowance')
        await this.token.connect(this.bob).approve(this.hat.address, '1500000000000000000')
        await this.hat.connect(this.bob).swapExactHatForAvaxWithFees('1500000000000000000', '0')
        expect((await this.hat.balanceOf(this.bob.address)).toString()).to.equal('17500000000000000000')
        expect((await this.hat.balanceOf(this.hat.address)).toString()).to.equal('1500000000000000000')


        // buys for 2000 avax
        const avaxAmount3 = '4000000000000000000000';
        const hatAmount = await this.hat.getHatAmountOutForExactAvaxAmountIn(avaxAmount3);
        await this.hat.connect(this.carol).swapExactAvaxForHat(hatAmount, {value: avaxAmount3})
        expect((await this.hat.balanceOf(this.carol.address)).toString()).to.equal((hatAmount).toString())
        expect((await this.hat.balanceOf(this.hat.address)).toString()).to.equal((new BN('1500000000000000000'))
            .sub((new BN(hatAmount.toString()))).toString())
    })

    after(async function () {
        await network.provider.request({
            method: 'hardhat_reset',
            params: [],
        });
    });
});
