const {ethers, network} = require("hardhat")
const {expect} = require("chai")

function getInt(value) {
    return parseInt(value._hex, 16)
}

describe("JoeHatBondingCurve", function () {
    before(async function () {
        this.JoeHatToken = await ethers.getContractFactory("JoeHatToken")
        this.JoeHatBondingCurve = await ethers.getContractFactory("JoeHatBondingCurve")
        this.JoeHatNFT = await ethers.getContractFactory("JoeHatNFT")
        this.signers = await ethers.getSigners()
        this.alice = this.signers[0]
        this.bob = this.signers[1]
        this.carol = this.signers[2]
        this.dave = this.signers[3]
        this.malaury = this.signers[4]
        this.susie = this.signers[5]
        this.owner = this.signers[6]
    })

    beforeEach(async function () {
        this.token = await this.JoeHatToken.deploy();
        await this.token.deployed();

        this.nft = await this.JoeHatNFT.deploy();
        await this.nft.deployed();

        this.hat = await this.JoeHatBondingCurve.deploy(this.nft.address, this.token.address, "30000000000000000000", "15000000000000000000")
        await this.hat.deployed()

        await this.token.transfer(this.hat.address, "150000000000000000000")
        await this.nft.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", this.hat.address)
    })

    it("should have correct totalSupply, reserveHat, reserveAvax, k, _a, _b", async function () {
        const results = await Promise.all([
            this.hat.totalSupply(),
            this.hat.reserveHat(),
            this.hat.reserveAvax(),
            this.hat.k(),
            this.hat._a(),
            this.hat._b()
        ])
        const totalSupply = getInt(results[0])
        const reserveHat = getInt(results[1])
        const reserveAvax = getInt(results[2])
        const k = getInt(results[3])
        const _a = getInt(results[4])
        const _b = getInt(results[5])

        // console.log(totalSupply, reserveHat, reserveAvax, k, _a, _b)

        expect(totalSupply).to.equal(150e18)
        expect(reserveHat).to.equal(150e18)
        expect(reserveAvax).to.equal(90e18)
        expect(k).to.equal(13500e18)
        expect(_a).to.equal(95)
        expect(_b).to.equal(100)
    })

    it("should have correct number of hat / avax when swapping", async function () {
        await this.hat.connect(this.bob).swapExactAvaxForHat({value: "10000000000000000000"})

        let results = await Promise.all([
            this.hat.balanceOf(this.bob.address),
            this.hat.balanceOf(this.hat.address),
            this.hat.reserveHat()
        ])
        expect(getInt(results[0])).to.equal(15000000000000000000)
        expect(getInt(results[1])).to.equal(135000000000000000000)
        expect(getInt(results[2])).to.equal(135000000000000000000)


        const avaxAmount = await this.hat.getAvaxAmountInForExactHatAmountOut("15000000000000000000")
        await this.hat.connect(this.bob).swapExactAvaxForHat({value: avaxAmount})
        results = await Promise.all([
            this.hat.balanceOf(this.bob.address),
            this.hat.balanceOf(this.hat.address),
            this.token.connect(this.bob).approve(this.hat.address, "30000000000000000000")
        ])
        expect(getInt(results[0])).to.equal(30000000000000000000)
        expect(getInt(results[1])).to.equal(120000000000000000000)

        await this.hat.connect(this.bob).swapExactHatForAvaxWithFees("15000000000000000000")
        results = await Promise.all([
            this.hat.balanceOf(this.bob.address),
            this.hat.balanceOf(this.hat.address)
        ])
        expect(getInt(results[0])).to.equal(15000000000000000000)
        expect(getInt(results[1])).to.equal(135000000000000000000)


        const hatAmount = await this.hat.getHatAmountInForExactAvaxAmountOutWithFees("9500000000000000000")
        await this.hat.connect(this.bob).swapExactHatForAvaxWithFees(hatAmount)
        results = await Promise.all([
            this.hat.balanceOf(this.bob.address),
            this.hat.balanceOf(this.hat.address)
        ])
        expect(getInt(results[0])).to.equal(0)
        expect(getInt(results[1])).to.equal(150000000000000000000)
    })


    it("should buy all the stock", async function () {
        // buys 148.6 hats
        const avaxAmount = await this.hat.getAvaxAmountInForExactHatAmountOut("148600000000000000000")
        await this.hat.connect(this.bob).swapExactAvaxForHat({value: avaxAmount})
        expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(148600000000000000000)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(1400000000000000000)


        // buys 0.6 hats
        const avaxAmount2 = await this.hat.getAvaxAmountInForExactHatAmountOut("600000000000000000")
        await this.hat.connect(this.alice).swapExactAvaxForHat({value: avaxAmount2})
        expect(getInt(await this.hat.balanceOf(this.alice.address))).to.equal(600000000000000000)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(800000000000000000)


        // buys the last 0.8 hats
        await this.hat.connect(this.dave).swapExactAvaxForHat({value: "9000000000000000000000"})
        await this.hat.connect(this.malaury).swapExactAvaxForHat({value: "9000000000000000000000"})
        await this.hat.connect(this.susie).swapExactAvaxForHat({value: "3600000000000000000000"})
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(1)


        // sells 0.6 hats
        await this.token.connect(this.alice).approve(this.hat.address, "30000000000000000000")
        await this.hat.connect(this.alice).swapExactHatForAvaxWithFees("600000000000000000")
        expect(getInt(await this.hat.balanceOf(this.alice.address))).to.equal(0)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(600000000000000000)


        // buys for 9 000 avax
        await this.hat.connect(this.carol).swapExactAvaxForHat({value: "9000000000000000000000"})
        expect(getInt(await this.hat.balanceOf(this.carol.address))).to.equal(333333333333333300)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(266666666666666660)
        expect(getInt(await this.hat.getHatAmountInForExactAvaxAmountOutWithFees("26550000000000000000000"))).to.equal(2255457227138643000)
        expect(getInt(await this.hat.getTeamBalance())).to.equal(810000000000000000000)

        // redeems 1 real Hat
        await this.token.connect(this.bob).approve(this.hat.address, "1000000000000000000")
        await this.hat.connect(this.bob).redeemHat()
        expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(147600000000000000000)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(266666666666666660)
        expect(getInt(await this.hat.getHatAmountInForExactAvaxAmountOutWithFees("26550000000000000000000"))).to.equal(2255457227138643000)
        expect(getInt(await this.hat.getTeamBalance())).to.equal(810604026845637600000)


        // withdraw team balance

        await expect(this.hat.connect(this.bob).withdrawTeamBalance()).to.be.revertedWith("Ownable: caller is not the owner")
        await this.hat.transferOwnership(this.owner.address)

        const prov = ethers.provider;
        const balance = await prov.getBalance(this.owner.address)
        await this.hat.connect(this.owner).withdrawTeamBalance()

        expect(await prov.getBalance(this.owner.address)).to.be.above(balance)
        expect(getInt(await this.hat.getTeamBalance())).to.equal(0)
    })

    it("Seeding the contract", async function () {
        await this.hat.seedAvax({value: "10000000000000000000"});
        expect(getInt(await this.hat.reserveAvax())).to.equal(100000000000000000000)

        await expect(this.hat.connect(this.bob).seedAvax({value: "10000000000000000000"})).to.be.revertedWith("Ownable: caller is not the owner")
    })

    after(async function () {
        await network.provider.request({
            method: "hardhat_reset",
            params: [],
        })
    })
})