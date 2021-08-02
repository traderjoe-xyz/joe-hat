const {ethers, network} = require("hardhat")
const {expect} = require("chai")

function getInt(value) {
    return parseInt(value._hex, 16)
}

describe("JoeHatContract", function () {
    before(async function () {
        this.JoeHatToken = await ethers.getContractFactory("JoeHatToken")
        this.JoeHatContract = await ethers.getContractFactory("JoeHatContract")
        this.signers = await ethers.getSigners()
        this.alice = this.signers[0]
        this.bob = this.signers[1]
        this.carol = this.signers[2]
        this.dave = this.signers[3]
        this.malaury = this.signers[4]
        this.susie = this.signers[5]
    })

    beforeEach(async function () {
        this.token = await this.JoeHatToken.deploy();
        await this.token.deployed();

        this.hat = await this.JoeHatContract.deploy(this.token.address, "30000000000000000000", "15000000000000000000")
        await this.hat.deployed()

        await this.token.transfer(this.hat.address, "150000000000000000000")
    })

    it("should have correct totalSupply, reserveHat, reserveAvax, k, _a, _b", async function () {
        const totalSupply = getInt(await this.hat.totalSupply())
        const reserveHat = getInt(await this.hat.reserveHat())
        const reserveAvax = getInt(await this.hat.reserveAvax())
        const k = getInt(await this.hat.k())
        const _a = getInt(await this.hat._a())
        const _b = getInt(await this.hat._b())

        // console.log(totalSupply, reserveHat, reserveAvax, k, _a, _b)

        expect(totalSupply).to.equal(150e18)
        expect(reserveHat).to.equal(150e18)
        expect(reserveAvax).to.equal(90e18)
        expect(k).to.equal(13500e18)
        expect(_a).to.equal(95)
        expect(_b).to.equal(100)
    })

    it("should have correct number of hat / avax when getSwapping", async function () {
        // const getExactAvaxForHat = getInt(await this.hat.getExactAvaxForHat("10000000000000000000"))
        // const getAvaxForExactHat = getInt(await this.hat.getAvaxForExactHat("15000000000000000000"))
        // const getHatForExactAvax = getInt(await this.hat.getHatForExactAvaxWithFees("10000000000000000000"))
        // const getExactHatForAvax = getInt(await this.hat.getExactHatForAvaxWithFees("15000000000000000000"))

        // console.log(getExactAvaxForHat, getAvaxForExactHat, getHatForExactAvax, getExactHatForAvax)

        // expect(getExactAvaxForHat).to.equal(15000000000000000000)
        // expect(getAvaxForExactHat).to.equal(10000000000000000000)
        // expect(getHatForExactAvax).to.equal(19736842105263157000)
        // expect(getExactHatForAvax).to.equal(7772727272727272000)
    })

    it("should have correct number of hat / avax when swapping", async function () {
        await this.hat.connect(this.bob).swapExactAvaxForHat({value: "10000000000000000000"})
        expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(15000000000000000000)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(135000000000000000000)
        expect(getInt(await this.hat.reserveHat())).to.equal(135000000000000000000)


        const avaxAmount = await this.hat.getAvaxForExactHat("15000000000000000000")
        await this.hat.connect(this.bob).swapExactAvaxForHat({value: avaxAmount})
        expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(30000000000000000000)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(120000000000000000000)


        await this.token.connect(this.bob).approve(this.hat.address, "30000000000000000000")
        await this.hat.connect(this.bob).swapExactHatForAvaxWithFees("15000000000000000000")
        expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(15000000000000000000)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(135000000000000000000)


        const hatAmount = await this.hat.getHatForExactAvaxWithFees("9500000000000000000")
        await this.hat.connect(this.bob).swapExactHatForAvaxWithFees(hatAmount)
        expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(0)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(150000000000000000000)
    })


    it("should buy all the stock", async function () {
        const avaxAmount = await this.hat.getAvaxForExactHat("148600000000000000000")
        await this.hat.connect(this.bob).swapExactAvaxForHat({value: avaxAmount})
        expect(getInt(await this.hat.balanceOf(this.bob.address))).to.equal(148600000000000000000)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(1400000000000000000)


        const avaxAmount2 = await this.hat.getAvaxForExactHat("600000000000000000")
        await this.hat.connect(this.alice).swapExactAvaxForHat({value: avaxAmount2})
        expect(getInt(await this.hat.balanceOf(this.alice.address))).to.equal(600000000000000000)
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(800000000000000000)


        await this.hat.connect(this.dave).swapExactAvaxForHat({value: "9000000000000000000000"})
        await this.hat.connect(this.malaury).swapExactAvaxForHat({value: "9000000000000000000000"})
        console.log(getInt(await this.hat.getAvaxForExactHat(await this.hat.balanceOf(this.hat.address))))
        await this.hat.connect(this.susie).swapExactAvaxForHat({value: "3600000000000000000000"})
        expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(0)

        // expect(getInt(await this.hat.balanceOf(this.alice.address))).to.equal(600000000000000000)
        // expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(800000000000000000)



        // const hatAmountlast = await this.hat.getExactAvaxForHat("21600000000000000000000")
        // const avaxAmountlast = await this.hat.getAvaxForExactHat("800000000000000000")
        // const avaxAmountSale = await this.hat._getExactHatForAvax("20000000000000000")
        // const hatAmountSale = await this.hat._getHatForExactAvax("540000000000000000000")
        // expect(getInt(hatAmountlast)).to.equal(800000000000000000)
        // expect(getInt(avaxAmountlast)).to.equal(21600000000000000000000)
        // expect(getInt(avaxAmountSale)).to.equal(540000000000000000000)
        // expect(getInt(hatAmountSale)).to.equal(20000000000000000)
        //
        //
        // await this.token.connect(this.alice).approve(this.hat.address, "30000000000000000000")
        // console.log(getInt(await this.alice.getBalance())/1e18)
        // await this.hat.connect(this.alice).swapExactHatForAvaxWithFees("600000000000000000")
        // console.log(getInt(await this.alice.getBalance())/1e18)
        // expect(getInt(await this.hat.balanceOf(this.alice.address))).to.equal(0)
        // expect(getInt(await this.hat.balanceOf(this.hat.address))).to.equal(1400000000000000000)
        //
        //
        // console.log(getInt(await this.carol.getBalance())/1e18)
        // await this.hat.connect(this.carol).swapExactAvaxForHat({value: "9257142857142858940416"})
        // console.log(getInt(await this.carol.getBalance())/1e18)
        // expect(getInt(await this.hat.balanceOf(this.carol.address))).to.equal(600000000000000100)
    })

    after(async function () {
        await network.provider.request({
            method: "hardhat_reset",
            params: [],
        })
    })
})