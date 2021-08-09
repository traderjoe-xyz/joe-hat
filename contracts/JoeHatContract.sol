// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Owners.sol";
import "./JoeHatToken.sol";


// Traderjoe's contract for $HAT
contract JoeHatContract is Owners, Context {
    /**
     * @notice a/b is between 0 and 1. During a sale, 1 - a/b is kept by the contract
     * so that it can be retrieved by the team and to encourage people to HODL
     */
    uint256 public _a = 95;
    uint256 public _b = 100;

    /// @notice k the constant of the uniswap curve.
    uint256 public k;
    uint256 public reserveAvax;
    uint256 public reserveHat;

    /** @notice used to calculate the amount of avax the contract needs to store
     * when initialising, it's equal to the reserveAvax (because there will never be more token).
     */
    uint256 public reserveLowestAvax;

    /**
     * @notice used to calculate the price of the very last token, because with uniswap
     * you'll never be able to buy the very last token, as it diverges to infinity, (1/0)
     */
    uint256 public lastHatPrice;

    /// @notice Max Supply of $HAT, when initialising, it's equal to the circulating supply.
    uint256 public maxSupply;

    /// @notice Keep a list of all the redeemers ordered by time. It will be used at some point...
    address[] public redeemers;

    /// @notice The contract that owns the token (because it was minted before this contract)
    JoeHatToken hatContract;

/**
 * @notice Constructor of the contract, needs the address of the $HAT token, the init supply
 * that the contract will own at start, and init price, the price in avax of the init supply.
 */
    constructor(address joeHatAddress, uint256 init_supply, uint256 init_price) {
        hatContract = JoeHatToken(joeHatAddress);

        /// @notice k = x*y = reserveHat * reserveAvax = init_supply * (init_supply * init_price)
        k = init_supply * init_supply / 1e18 * init_price / 1e18;

        /**
         * @notice we calculate the reserveHat and reserveAvax as if all the tokens were
         * owned by the smart contract
         */
        reserveHat = totalSupply();
        maxSupply = reserveHat;
        reserveAvax = k * 1e18 / totalSupply();
        reserveLowestAvax = reserveAvax;

        /// @notice we chose the last hat to be priced 4 times the price of the one before
        lastHatPrice = k * 2;
    }

    /// @notice Function used when $HAT tokens are added to the pool, i.e. when they are sold.
    function addHat(uint256 hatAdded, uint256 avaxRemoved) private {
        require(reserveHat + hatAdded <= totalSupply(), "Too much hat added");
        reserveHat += hatAdded;
        reserveAvax -= avaxRemoved;
    }

    /// @notice Function used when $HAT tokens are removed from the pool, i.e. when they are bought.
    function removeHat(uint256 hatRemoved, uint256 avaxAdded) private {
        reserveHat -= hatRemoved;
        reserveAvax += avaxAdded;
    }

    /**
     * @notice VERY IMPORTANT : this needs to be called to seed the contract.
     * if all the tokens are owned by the contract, i.e. not any of the token were or will be given, then
     * you don't need to seed the contract.
     * But if some tokens were given or will be, this needs to be called with the exact value of the $HAT token that
     * were given so that if everyone sells its token, the contract have enough avax for this.
     */
    function seedAvax() external payable onlyOwners {
        removeHat(getExactAvaxForHat(msg.value), msg.value);
        emit SeedAvax(_msgSender(), msg.value);
    }

    /// @notice Function used to buy $HAT with Avax.
    function swapAvaxForHat(uint256 avaxAmount, uint256 hatAmount) private {
        hatContract.approve(_msgSender(), hatAmount);
        hatContract.transfer(_msgSender(), hatAmount);

        removeHat(hatAmount, msg.value);

        emit SwapAvaxForHat(avaxAmount, hatAmount);
    }

    /**
     * @notice Function used to buy $HAT with ExactAvax.
     * User send X avax, the contract calculate how much $HAT he will receive.
     */
    function swapExactAvaxForHat() external payable returns (bool) {
        uint256 hatAmount = getExactAvaxForHat(msg.value);

        swapAvaxForHat(msg.value, hatAmount);

        return true;
    }

    /**
     * @notice Function used to sell $HAT with Avax.
     * User send X avax, the contract calculate how much $HAT he will receive.
     */
    function swapExactHatForAvaxWithFees(uint256 hatAmount) external returns (bool) {
        uint256 avaxAmount = _getExactHatForAvax(hatAmount);
        uint256 avaxAmountWithFees = getExactHatForAvaxWithFees(hatAmount);

        hatContract.transferFrom(_msgSender(), address(this), hatAmount);
        payable(_msgSender()).transfer(avaxAmountWithFees);

        addHat(hatAmount, avaxAmount);

        emit SwapHatForAvax(hatAmount, avaxAmountWithFees);
        return true;
    }

    /**
     * @notice Function used to get $HAT amount for a given amount of Avax.
     * only for the last Hat
     */
    function _getExactAvaxForLastHat(uint256 avaxAmount) private view returns (uint256) {
        return avaxAmount * 1e18 / lastHatPrice;
    }

    /**
     * @notice Function used to get Avax amount for a given amount of $HAT.
     * only for the last Hat
     */
    function _getAvaxForExactLastHat(uint256 hatAmount) private view returns (uint256) {
        return lastHatPrice / 1e18 * hatAmount;
    }

    /**
     * @notice Function used to get Avax amount for a given amount of $HAT.
     * for [1, 150] hats.
     */
    function getExactAvaxForHat(uint256 avaxAmount) public view returns (uint256) {
        require(reserveAvax + avaxAmount <= k + lastHatPrice, "getExactAvaxForHat: Not enough hat in reserve");
        // this is added for the VERY last hat
        if (reserveAvax + avaxAmount > k) {
            uint256 hatAmountOld = 0;
            uint256 avaxAmountOld = 0;
            if (reserveAvax < k) {
                avaxAmountOld = k - reserveAvax;
                hatAmountOld = getExactAvaxForHat(avaxAmountOld);
            }
            uint256 hatAmountNew = _getExactAvaxForLastHat(avaxAmount - avaxAmountOld);
            return hatAmountOld + hatAmountNew;
        }
        return k * 1e18 / reserveAvax - k * 1e18 / (reserveAvax + avaxAmount);
    }

    function getAvaxForExactHat(uint256 hatAmount) public view returns (uint256) {
        require(reserveHat >= hatAmount, "getAvaxForExactHat: Not enough HAT in reserve");
        // this is added for the VERY last hat
        if (reserveHat - hatAmount < 1e18) {
            uint256 avaxAmountOld = 0;
            uint256 hatAmountOld = 0;
            if (reserveHat > 1e18) {
                hatAmountOld = reserveHat - 1e18;
                avaxAmountOld = getAvaxForExactHat(hatAmountOld);
            }
            uint256 avaxAmountNew = _getAvaxForExactLastHat(hatAmount - hatAmountOld);
            return avaxAmountOld + avaxAmountNew;
        }
        return k * 1e18 / (reserveHat - hatAmount) - k * 1e18 / reserveHat;
    }

    function getHatForExactAvaxWithFees(uint256 avaxAmount) public view returns (uint256) {
        uint256 avaxAmountWithFees = avaxAmount * _b / _a;

        uint256 hatAmountWithFees = _getHatForExactAvax(avaxAmountWithFees);
        require(reserveHat + hatAmountWithFees <= maxSupply, "getHatForExactAvaxWithFees : Too much hat sold");
        return hatAmountWithFees;
    }

    function getExactHatForAvaxWithFees(uint256 hatAmount) public view returns (uint256) {
        require(reserveHat + hatAmount <= maxSupply, "getExactHatForAvaxWithFees : Too much hat sold");
        return _getExactHatForAvax(hatAmount * _a / _b);
    }

    function _getHatForExactAvax(uint256 avaxAmount) private view returns (uint256) {
        require(reserveAvax - reserveLowestAvax >= avaxAmount, "_getHatForExactAvax: Too many hat sold");
        if (reserveAvax > k) {// if there is less than 1 hats in the pool
            uint256 hatAmountNew = 0;
            uint256 hatAmountOld = 0;
            if (reserveAvax - avaxAmount < k) {
                hatAmountNew = _getExactAvaxForLastHat(reserveAvax - k);
                hatAmountOld = _getBeforeLastHatForExactAvax(avaxAmount - (reserveAvax - k));
            }
            else {
                hatAmountNew = _getExactAvaxForLastHat(avaxAmount);
            }
            return hatAmountOld + hatAmountNew;
        }

        return (k * 1e18 / (reserveAvax - avaxAmount) - k * 1e18 / reserveAvax);
    }

    function _getExactHatForAvax(uint256 hatAmount) private view returns (uint256) {
        if (reserveHat < 1e18) {
            uint256 avaxAmountNew = 0;
            uint256 avaxAmountOld = 0;
            if (reserveHat + hatAmount > 1e18) {
                avaxAmountNew = _getAvaxForExactLastHat(1e18 - reserveHat);
                avaxAmountOld = _getExactBeforeLastHatForAvax(reserveHat + hatAmount - 1e18);
            }
            else {
                avaxAmountNew = _getAvaxForExactLastHat(hatAmount);
            }
            return avaxAmountOld + avaxAmountNew;
        }
        return (k * 1e18 / reserveHat - k * 1e18 / (reserveHat + hatAmount));
    }

    function _getBeforeLastHatForExactAvax(uint256 avaxAmount) private view returns (uint256) {
        return k * 1e18 / (k - avaxAmount) - 1e18;
    }

    function _getExactBeforeLastHatForAvax(uint256 hatAmount) private view returns (uint256) {
        return k - k * 1e18 / (1e18 + hatAmount);
    }

    function teamWithdraw() public onlyOwners {
        uint256 teamBalance = getWithdrawableByTeam();
        payable(_msgSender()).transfer(teamBalance);
        emit TeamWithdraw(teamBalance);
    }

    function getWithdrawableByTeam() public view returns (uint256) {
        return address(this).balance - _getExactHatForAvax(totalSupply() - balanceOf(address(this)));
    }

    function balanceOf(address account) public view returns (uint256){
        return hatContract.balanceOf(account);
    }

    function totalSupply() public view returns (uint256) {
        return hatContract.totalSupply();
    }

    function burn(uint256 hatAmount) public {
        hatContract.burnFrom(_msgSender(), hatAmount);
    }

    function redeemHat() public { // only owners ? needs to be called only by the website ?
        hatContract.burnFrom(_msgSender(), 1e18);
        redeemers.push(_msgSender());
    }

    event SeedAvax(address sender, uint256 valueAVAX);
    event GetNewHat(uint256 oldBalance);
    event SwapAvaxForHat(uint256 avaxAmount, uint256 hatAmount);
    event SwapHatForAvax(uint256 hatAmount, uint256 avaxAmount);
    event TeamWithdraw(uint256 teamBalance);
}