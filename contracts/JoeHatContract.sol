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
    uint256 public lastHatPriceInAvax;

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
        lastHatPriceInAvax = k * 2;
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

    /// @notice Function used to buy $HAT with Avax. Needs to be private and called from other functions.
    function swapAvaxForHat(uint256 avaxAmount, uint256 hatAmount) private {
        // we approve the exact amount we send to the _msgSender
        hatContract.approve(_msgSender(), hatAmount);
        // we transfer them that amount
        hatContract.transfer(_msgSender(), hatAmount);

        // we remove it from the pool reserve
        removeHat(hatAmount, msg.value);

        emit SwapAvaxForHat(avaxAmount, hatAmount);
    }

    /**
     * @notice Function used to buy $HAT with ExactAvax.
     * `sender` sends X avax, the contract calculate how much $HAT he will receive.
     * And it sends them to the caller.
     */
    function swapExactAvaxForHat() external payable returns (bool) {
        uint256 hatAmount = getExactAvaxForHat(msg.value);

        swapAvaxForHat(msg.value, hatAmount);

        return true;
    }

    /**
     * @notice Function used to sell $HAT for Avax.
     * `sender` send X $HAT, the contract calculate how much Avax he will receive.
     * And it sends them to the caller.
     */
    function swapExactHatForAvaxWithFees(uint256 hatAmount) external returns (bool) {
        // Amount that should be sent to the _msgSender, used for the reserveAvax of the contract
        uint256 avaxAmount = _getExactHatForAvax(hatAmount);

        // Amount that is sent to the _msgSender, approx equal to avaxAmount*a/b
        uint256 avaxAmountWithFees = getExactHatForAvaxWithFees(hatAmount);

        // The `sender` sends the token to the contract
        hatContract.transferFrom(_msgSender(), address(this), hatAmount);
        //the contract sends Avax to the _msgSender.
        payable(_msgSender()).transfer(avaxAmountWithFees);

        // we add the hat amount to the reserve, and remove the avax that we sent.
        addHat(hatAmount, avaxAmount);

        emit SwapHatForAvax(hatAmount, avaxAmountWithFees);
        return true;
    }

    /**
     * @notice Function used to get $HAT amount for a given amount of Avax.
     * only for the last Hat. HatSent = AvaxSent / LastHatPriceInAvax
     */
    function _getExactAvaxForLastHat(uint256 avaxAmount) private view returns (uint256) {
        return avaxAmount * 1e18 / lastHatPriceInAvax;
    }

    /**
     * @notice Function used to get Avax amount for a given amount of $HAT.
     * only for the last Hat. AvaxSent = HatSent * LastHatPriceInAvax
     */
    function _getAvaxForExactLastHat(uint256 hatAmount) private view returns (uint256) {
        return lastHatPriceInAvax * hatAmount / 1e18;
    }

    /**
     * @notice Function used to get $HAT amount for a given amount of Avax.
     * used to buy HAT with Avax.
     */
    function getExactAvaxForHat(uint256 avaxAmount) public view returns (uint256) {
        require(reserveAvax + avaxAmount <= k + lastHatPriceInAvax, "getExactAvaxForHat: Not enough hat in reserve");
        // this is added for the VERY last hat
        // This tests if when user buy that amount he will be buying at least a bit of the last Hat
        // it needs to check this because the last hat doesn't use the same function
        if (reserveAvax + avaxAmount > k) {
            uint256 hatAmountOld = 0;
            uint256 avaxAmountOld = 0;
            // This tests if the `sender` will buy some hats before the last one,
            // if so it needs to get the price of the previous ones independently
            if (reserveAvax < k) {
                avaxAmountOld = k - reserveAvax;
                hatAmountOld = reserveHat - 1e18;
            }
            uint256 hatAmountNew = _getExactAvaxForLastHat(avaxAmount - avaxAmountOld);
            return hatAmountOld + hatAmountNew;
        }
        // uniswap curve
        return k * 1e18 / reserveAvax - k * 1e18 / (reserveAvax + avaxAmount);
    }

    /**
     * @notice Function used to get Avax amount for a given amount of $HAT.
     * used to buy HAT with Avax.
     */
    function getAvaxForExactHat(uint256 hatAmount) public view returns (uint256) {
        require(reserveHat >= hatAmount, "getAvaxForExactHat: Not enough HAT in reserve");
        // this is added for the VERY last hat
        // This tests if when user buy that amount he will be buying at least a bit of the last Hat
        // it needs to check this because the last hat doesn't use the same function
        if (reserveHat - hatAmount < 1e18) {
            uint256 avaxAmountOld = 0;
            uint256 hatAmountOld = 0;
            // This tests if the `sender` will buy some hats before the last one,
            // if so it needs to get the price of the previous ones independently
            if (reserveHat > 1e18) {
                hatAmountOld = reserveHat - 1e18;
                avaxAmountOld = k - reserveAvax;
            }
            uint256 avaxAmountNew = _getAvaxForExactLastHat(hatAmount - hatAmountOld);
            return avaxAmountOld + avaxAmountNew;
        }
        // uniswap curve
        return k * 1e18 / (reserveHat - hatAmount) - k * 1e18 / reserveHat;
    }

    /**
     * @notice Function used to get $HAT amount for a given amount of Avax with fees,
     * approx a*b more hat needed for the same avax amount if that was without fees.
     * used when selling Hat for Avax.
     */
    function getHatForExactAvaxWithFees(uint256 avaxAmount) public view returns (uint256) {
        // fees are calculated by increasing the amount of Avax that the user want to receive,
        // to increase artificially the amount of Hat he needs to send, approx a/b more.
        uint256 avaxAmountWithFees = avaxAmount * _b / _a;
        uint256 hatAmountWithFees = _getHatForExactAvax(avaxAmountWithFees);

        require(reserveHat + hatAmountWithFees <= maxSupply, "getHatForExactAvaxWithFees : Too much hat sold");
        return hatAmountWithFees;
    }

    /**
     * @notice Function used to get Avax amount for a given amount of $HAT,
     * approx a*b less Avax than for the same hat amount is that was without fees.
     * used when selling HAT for Avax.
     */
    function getExactHatForAvaxWithFees(uint256 hatAmount) public view returns (uint256) {
        require(reserveHat + hatAmount <= maxSupply, "getExactHatForAvaxWithFees : Too much hat sold");
        return _getExactHatForAvax(hatAmount * _a / _b);
    }

    /**
     * @notice Function used to get $HAT amount for a given amount of Avax.
     * used when selling HAT for Avax.
     */
    function _getHatForExactAvax(uint256 avaxAmount) private view returns (uint256) {
        require(reserveAvax - reserveLowestAvax >= avaxAmount, "_getHatForExactAvax: Too many hat sold");
        // this is added for the VERY last hat
        // This tests if when user buy that amount he will be buying at least a bit of the last Hat
        // it needs to check this because the last hat doesn't use the same function
        if (reserveAvax > k) {// if there is less than 1 hats in the pool
            uint256 hatAmountNew = 0;
            uint256 hatAmountOld = 0;
            // This tests if the `sender` will buy some hats before the last one,
            // if so it needs to get the price of the previous ones independently
            if (reserveAvax - avaxAmount < k) {
                // it's harder because it's in the opposite side, and so I added a new function
                hatAmountNew = _getExactAvaxForLastHat(reserveAvax - k);
                hatAmountOld = _getBeforeLastHatForExactAvax(avaxAmount - (reserveAvax - k));
            }
            else {
                hatAmountNew = _getExactAvaxForLastHat(avaxAmount);
            }
            return hatAmountOld + hatAmountNew;
        }
        // uniswap curve
        return (k * 1e18 / (reserveAvax - avaxAmount) - k * 1e18 / reserveAvax);
    }

    /**
     * @notice Function used to get Avax amount for a given amount of $HAT.
     * Used when selling HAT for Avax.
     */
    function _getExactHatForAvax(uint256 hatAmount) private view returns (uint256) {
        // this is added for the VERY last hat
        // This tests if when user buy that amount he will be buying at least a bit of the last Hat
        // it needs to check this because the last hat doesn't use the same function
        if (reserveHat < 1e18) {
            uint256 avaxAmountNew = 0;
            uint256 avaxAmountOld = 0;
            // This tests if the `sender` will buy some hats before the last one,
            // if so it needs to get the price of the previous ones independently
            if (reserveHat + hatAmount > 1e18) {
                avaxAmountNew = _getAvaxForExactLastHat(1e18 - reserveHat);
                avaxAmountOld = _getExactBeforeLastHatForAvax(reserveHat + hatAmount - 1e18);
            }
            else {
                avaxAmountNew = _getAvaxForExactLastHat(hatAmount);
            }
            return avaxAmountOld + avaxAmountNew;
        }
        // uniswap curve
        return (k * 1e18 / reserveHat - k * 1e18 / (reserveHat + hatAmount));
    }

    /**
     * @notice Function used to get $HAT amount for a given amount of Avax.
     * used when selling Hat for Avax.
     */
    function _getBeforeLastHatForExactAvax(uint256 avaxAmount) private view returns (uint256) {
        return k * 1e18 / (k - avaxAmount) - 1e18;
    }

    /**
     * @notice Function used to get Avax amount for a given amount of $HAT.
     * used when selling Hat for Avax.
     */
    function _getExactBeforeLastHatForAvax(uint256 hatAmount) private view returns (uint256) {
        return k - k * 1e18 / (1e18 + hatAmount);
    }


    /**
     * @notice Function used to withdraw the team funds, this is equal to the amount of Avax kept by the contract
     * that aren't needed if everyone sells their tokens.
     */
    function teamWithdraw() public onlyOwners {
        uint256 teamBalance = getWithdrawableByTeam();
        payable(_msgSender()).transfer(teamBalance);
        emit TeamWithdraw(teamBalance);
    }

    /**
     * @notice Function used to get the team amount, it's calculated by taking the Avax balance of the contract
     * and removing the Avax needed to pay everyone if all HODLers would like to sell al their tokens.
     */
    function getWithdrawableByTeam() public view returns (uint256) {
        return address(this).balance - _getExactHatForAvax(totalSupply() - balanceOf(address(this)));
    }
    /**
     * @notice Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view returns (uint256){
        return hatContract.balanceOf(account);
    }
    /**
     * @notice Returns the amount of tokens in existence.
     */
    function totalSupply() public view returns (uint256) {
        return hatContract.totalSupply();
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function burn(uint256 hatAmount) public {
        hatContract.burnFrom(_msgSender(), hatAmount);
    }

    /**
     * @notice used to redeem a real hat, that will burn 1 $hat.
     * `sender` needs at least 1 $HAT.
     */
    function redeemHat() public { // only owners ? needs to be called only by the website ?
        hatContract.burnFrom(_msgSender(), 1e18);
        redeemers.push(_msgSender());
    }

    /**
     * @notice Emitted when an owner seed the contract with valueAvax Avax.
     */
    event SeedAvax(address sender, uint256 valueAVAX);

    /**
     * @notice Emitted swapping Avax for Hat.
     */
    event SwapAvaxForHat(uint256 avaxAmount, uint256 hatAmount);

    /**
     * @notice Emitted swapping Hat for Avax.
     */
    event SwapHatForAvax(uint256 hatAmount, uint256 avaxAmount);

    /**
     * @notice Emitted when an owner withdraw the tokens of the team balance.
     */
    event TeamWithdraw(uint256 teamBalance);
}