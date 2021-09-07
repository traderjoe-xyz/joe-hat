// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./JoeHatToken.sol";
import "./JoeHatNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Trader Joe's bonding curve contract for the HAT token.
 * @notice Allows buying/selling of HATs to AVAX along a bonding curve.
 * @author LouisMeMyself
 */
contract JoeHatBondingCurve is Ownable {
    /// @notice a/b is between 0 and 1. During a sale, 1 - a/b is kept by the contract
    /// so that it can be retrieved by the team and to encourage people to HODL.
    uint256 public _a = 95;
    uint256 public _b = 100;

    /// @notice k the constant of the uniswap curve.
    uint256 public k;
    uint256 public reserveAvax;
    uint256 public reserveHat;

    /// @notice Used to calculate the amount of avax the contract needs to store
    /// when initialising, it's equal to the reserveAvax (because there will never be more token).
    uint256 public reserveLowestAvax;

    /// @notice Used to calculate the price of the very last token, because with uniswap
    /// you'll never be able to buy the very last token, as it diverges to infinity, (1/0)
    uint256 public lastHatPriceInAvax;

    /// @notice Max Supply of HAT, when initialising, it's equal to the circulating supply.
    uint256 public maxSupply;

    /// @notice Keep a list of all the redeemers ordered by time. It will be used at some point...
    address[] public redeemers;

    JoeHatToken hatToken;
    JoeHatNFT hatNft;


    /**
     * @notice Constructor of the contract, 
     * @param joeHatAddress - Address of the joeHatContract.
     * @param initialHatSupply - HAT initial supply.
     * @param initialHatPrice - HAT initial price in AVAX.
     */
    constructor(address joeHatNftAddress, address joeHatAddress, uint256 initialHatSupply, uint256 initialHatPrice) {
        hatToken = JoeHatToken(joeHatAddress);
        hatNft = JoeHatNFT(joeHatNftAddress);

        /// @notice k = x*y = reserveHat * reserveAvax = initialHatSupply * (initialHatSupply * initialHatPrice).
        k = initialHatSupply * initialHatSupply / 1e18 * initialHatPrice / 1e18;


        /// @notice we calculate the reserveHat and reserveAvax as if all the tokens were
        /// owned by the smart contract.
        reserveHat = totalSupply();
        maxSupply = reserveHat;
        reserveAvax = k * 1e18 / totalSupply();
        reserveLowestAvax = reserveAvax;

        /// @notice we chose the last hat to be priced 4 times the price of the one before.
        lastHatPriceInAvax = k * 2;
    }

    /*** Public Hooks ***/

    /**
     * @notice Sells a given amount of AVAX for HAT.
     * @return true - If swap was successful.
     */
    function swapExactAvaxForHat() external payable returns (bool) {
        uint256 hatAmount = getHatAmountOutForExactAvaxAmountIn(msg.value);

        hatToken.transfer(_msgSender(), hatAmount);

        _removeHat(hatAmount, msg.value);

        emit SwapAvaxForHat(avaxAmount, hatAmount);
        return true;
    }

    /**
     * @notice Buys a given amount of HAT for AVAX.
     */
    function swapAvaxForExactHat() {
      // TODO
    }

    /**
     * @notice Sells a given amount of HAT for AVAX with fees deducted.
     * @param hatAmount - The amount of HAT to swap for AVAX.
     * @return true - If swap was successful.
     */
    function swapExactHatForAvaxWithFees(uint256 hatAmount) external returns (bool) {
        /// Amount that should be sent to the _msgSender, used for the reserveAvax of the contract
        uint256 avaxAmount = _getAvaxAmountOutForExactHatAmountIn(hatAmount);

        /// Amount that is sent to the _msgSender, approx equal to avaxAmount*a/b
        uint256 avaxAmountWithFees = getAvaxAmountOutForExactHatAmountInWithFees(hatAmount);

        hatToken.transferFrom(_msgSender(), address(this), hatAmount);
        payable(_msgSender()).transfer(avaxAmountWithFees);

        /// we add the hat amount to the reserve, and remove the avax that we sent.
        _addHat(hatAmount, avaxAmount);

        emit SwapHatForAvax(hatAmount, avaxAmountWithFees);
        return true;
    }

    /**
     * @notice Buys a given amount of AVAX for HAT with fees deducted.
     */
    function swapHatForExactAvaxWithFees() {
      // TODO
    }

    /**
     * @notice Calculates the amount of HAT received if a given amount of AVAX is sold.
     * @param avaxAmount - The amount of AVAX sold.
     * @return hatAmount - The amount of HAT received.
     */
    function getHatAmountOutForExactAvaxAmountIn(uint256 avaxAmount) public view returns (uint256) {
        require(reserveAvax + avaxAmount <= k + lastHatPriceInAvax, "getHatAmountOutForExactAvaxAmountIn: Not enough hat in reserve");
        /// this is added for the VERY last hat
        /// This tests if when user buy that amount he will be buying at least a bit of the last Hat
        /// it needs to check this because the last hat doesn't use the same function
        if (reserveAvax + avaxAmount > k) {
            uint256 hatAmountOld = 0;
            uint256 avaxAmountOld = 0;
            /// This tests if the `sender` will buy some hats before the last one,
            /// if so it needs to get the price of the previous ones independently
            if (reserveAvax < k) {
                avaxAmountOld = k - reserveAvax;
                hatAmountOld = reserveHat - 1e18;
            }
            uint256 hatAmountNew = _getLastHatAmountForExactAvaxAmount(avaxAmount - avaxAmountOld);
            return hatAmountOld + hatAmountNew;
        }
        return k * 1e18 / reserveAvax - k * 1e18 / (reserveAvax + avaxAmount);
    }

    /**
     * @notice Calculates the required amount of AVAX to buy a given amount of HAT.
     * @param hatAmount - The amount of HAT to buy.
     * @return avaxAmount - The amount of AVAX required.
     */
    function getAvaxAmountInForExactHatAmountOut(uint256 hatAmount) public view returns (uint256) {
        require(reserveHat >= hatAmount, "getAvaxAmountInForExactHatAmountOut: Not enough HAT in reserve");
        /// this is added for the VERY last hat
        /// This tests if when user buy that amount he will be buying at least a bit of the last Hat
        /// it needs to check this because the last hat doesn't use the same function
        if (reserveHat - hatAmount < 1e18) {
            uint256 avaxAmountOld = 0;
            uint256 hatAmountOld = 0;
            /// This tests if the `sender` will buy some hats before the last one,
            /// if so it needs to get the price of the previous ones independently
            if (reserveHat > 1e18) {
                hatAmountOld = reserveHat - 1e18;
                avaxAmountOld = k - reserveAvax;
            }
            uint256 avaxAmountNew = _getAvaxAmountForLastExactHatAmount(hatAmount - hatAmountOld);
            return avaxAmountOld + avaxAmountNew;
        }
        return k * 1e18 / (reserveHat - hatAmount) - k * 1e18 / reserveHat;
    }

    /**
     * @notice Calculates the received amount of AVAX if a given amount of HAT is sold with fees
     * deducted.
     * @param hatAmount - The amount of HAT to sell.
     * @return avaxAmount - The amount of AVAX received.
     */
    function getAvaxAmountOutForExactHatAmountInWithFees(uint256 hatAmount) public view returns (uint256) {
        require(reserveHat + hatAmount <= maxSupply, "getAvaxAmountOutForExactHatAmountInWithFees : Too much hat sold");
        return _getAvaxAmountOutForExactHatAmountIn(hatAmount * _a / _b);
    }

    /**
     * @notice Calculates the required amount of HAT to buy a given an amount of AVAX with fees 
     * taken into account.
     * @param avaxAmount - The amount of AVAX to buy.
     * @return hatAmount - The amount of HAT required.
     */
    function getHatAmountInForExactAvaxAmountOutWithFees(uint256 avaxAmount) public view returns (uint256) {
        uint256 avaxAmountWithFees = avaxAmount * _b / _a;
        uint256 hatAmountWithFees = _getHatAmountInForExactAvaxAmountOut(avaxAmountWithFees);

        require(reserveHat + hatAmountWithFees <= maxSupply, "getHatAmountInForExactAvaxAmountOutWithFees : Too much hat sold");
        return hatAmountWithFees;
    }


    /*** Private hooks ***/

    /**
     * @notice Updates virtual reserves when HATs are added and AVAX subsequently removed.
     * @dev AVAX reserve is less than actual balance of AVAX held by contract.
     * @param hatAdded - The number of HATs to add to reserve.
     * @param avaxRemoved - The number of AVAX to remove from reserve.
     */
    function _addHat(uint256 hatAdded, uint256 avaxRemoved) private {
        require(reserveHat + hatAdded <= totalSupply(), "Too much hat added");
        reserveHat += hatAdded;
        reserveAvax -= avaxRemoved;
    }

    /**
     * @notice Updates virtual reserves when HATs are removed and AVAX subsequently added.
     * @dev AVAX reserve is less than actual balance of AVAX held by contract.
     * @param hatRemoved - The number of HATs to remove from reserve.
     * @param avaxAdded - The number of AVAX to add to reserve.
     */
    function _removeHat(uint256 hatRemoved, uint256 avaxAdded) private {
        reserveHat -= hatRemoved;
        reserveAvax += avaxAdded;
    }

    /**
     * @notice Calculates the amount of AVAX received if a given amount of HAT is sold.
     * @dev This is a helper function used in swapExactHatForAvaxWithFees and 
     * getAvaxAmountOutForExactHatAmountInWithFees.
     * @param hatAmount - The amount of HAT to sell.
     * @return avaxAmount - The amount of AVAX received.
     */
    function _getAvaxAmountOutForExactHatAmountIn(uint256 hatAmount) private view returns (uint256) {
        /// this is added for the VERY last hat
        /// This tests if when user buy that amount he will be buying at least a bit of the last Hat
        /// it needs to check this because the last hat doesn't use the same function
        if (reserveHat < 1e18) {
            uint256 avaxAmountNew = 0;
            uint256 avaxAmountOld = 0;
            /// This tests if the `sender` will buy some hats before the last one,
            /// if so it needs to get the price of the previous ones independently
            if (reserveHat + hatAmount > 1e18) {
                avaxAmountNew = _getAvaxAmountForLastExactHatAmount(1e18 - reserveHat);
                avaxAmountOld = _getAvaxAmountOutForExactHatAmountInBeforeLastHat(reserveHat + hatAmount - 1e18);
            }
            else {
                avaxAmountNew = _getAvaxAmountForLastExactHatAmount(hatAmount);
            }
            return avaxAmountOld + avaxAmountNew;
        }
        return (k * 1e18 / reserveHat - k * 1e18 / (reserveHat + hatAmount));
    }

    /**
     * @notice Calculates the received amount of AVAX for a given amount of HAT sold before the last HAT.
     * @dev This is a helper function used in _getAvaxAmountOutForExactHatAmountIn.
     * @param hatAmount - The amount of HAT to sell.
     * @return avaxAmount - The amount of AVAX received.
     */
    function _getAvaxAmountOutForExactHatAmountInBeforeLastHat(uint256 hatAmount) private view returns (uint256) {
        return k - k * 1e18 / (1e18 + hatAmount);
    }

    /**
     * @notice Calculates amount of AVAX received for given amount of the last HAT.
     * @dev This is a helper function used in getAvaxAmountInForExactHatAmountOut and 
     * _getAvaxAmountOutForExactHatAmountIn.
     * @param hatAmount - The amount of last HAT to swap for AVAX.
     * @return avaxAmount - The amount of AVAX received.
     */
    function _getAvaxAmountForLastExactHatAmount(uint256 hatAmount) private view returns (uint256) {
        return lastHatPriceInAvax * hatAmount / 1e18;
    }

    /**
     * @notice Calculates the required amount of HAT to buy a given an amount of AVAX.
     * @dev This is a helper function used in getHatAmountInForExactAvaxAmountOutWithFees.
     * @param avaxAmount - The amount of AVAX to buy.
     * @return hatAmount - The amount of HAT required.
     */
    function _getHatAmountInForExactAvaxAmountOut(uint256 avaxAmount) private view returns (uint256) {
        require(reserveAvax - reserveLowestAvax >= avaxAmount, "_getHatAmountInForExactAvaxAmountOut: Too many hat sold");
        /// this is added for the VERY last hat
        /// This tests if when user buy that amount he will be buying at least a bit of the last Hat
        /// it needs to check this because the last hat doesn't use the same function
        if (reserveAvax > k) {// if there is less than 1 hats in the pool
            uint256 hatAmountNew = 0;
            uint256 hatAmountOld = 0;
            /// This tests if the `sender` will buy some hats before the last one,
            /// if so it needs to get the price of the previous ones independently
            if (reserveAvax - avaxAmount < k) {
                /// it's harder because it's in the opposite side, and so I added a new function
                hatAmountNew = _getLastHatAmountForExactAvaxAmount(reserveAvax - k);
                hatAmountOld = _getHatAmountInForExactAvaxAmountOutBeforeLastHat(avaxAmount - (reserveAvax - k));
            }
            else {
                hatAmountNew = _getLastHatAmountForExactAvaxAmount(avaxAmount);
            }
            return hatAmountOld + hatAmountNew;
        }
        return (k * 1e18 / (reserveAvax - avaxAmount) - k * 1e18 / reserveAvax);
    }

    /**
     * @notice Calculates the required amount of HAT to buy a given amount of AVAX before 
     * the last HAT.
     * @dev This is a helper function used in _getHatAmountInForExactAvaxAmountOut.
     * @param avaxAmount - The amount of AVAX to buy.
     * @return hatAmount - The amount of HAT required.
     */
    function _getHatAmountInForExactAvaxAmountOutBeforeLastHat(uint256 avaxAmount) private view returns (uint256) {
        return k * 1e18 / (k - avaxAmount) - 1e18;
    }

    /**
     * @notice Calculates amount of last HAT received for a given amount of AVAX.
     * @dev This is a helper function used in getHatAmountOutForExactAvaxAmountIn and 
     * _getHatAmountInForExactAvaxAmountOut.
     * @param avaxAmount - The AVAX amount to swap for the last HAT.
     * @return lastHatAmount - The amount of the last HAT received.
     */
    function _getLastHatAmountForExactAvaxAmount(uint256 avaxAmount) private view returns (uint256) {
        return avaxAmount * 1e18 / lastHatPriceInAvax;
    }


    /*** Admin functions ***/

    /**
     * @notice Adds AVAX to the contract.
     * @dev VERY IMPORTANT : this needs to be called to seed the contract.
     * if all the tokens are owned by the contract, i.e. not any of the token were or will be given, then
     * you don't need to seed the contract.
     * But if some tokens were given or will be, this needs to be called with the exact value of the 
     * HAT token that were given so that if everyone sells its token, the contract have enough avax 
     * for this.
     */
    function seedAvax() external payable onlyOwner {
        _removeHat(getHatAmountOutForExactAvaxAmountIn(msg.value), msg.value);
        emit SeedAvax(_msgSender(), msg.value);
    }

    /**
     * @notice Withdraws the team funds, which is equal to the amount of AVAX kept by 
     * the contract that aren't needed if everyone sells their tokens.
     */
    function withdrawTeamBalance() public onlyOwner {
        uint256 teamBalance = getTeamBalance();
        payable(_msgSender()).transfer(teamBalance);
        emit TeamWithdraw(teamBalance);
    }

    /*** Token functions ***/

    /**
     * @notice Gets the team AVAX balance, which is calculated by taking the AVAX 
     * balance of the contract and removing the AVAX needed to pay everyone if all 
     * HODLers sell all their tokens.
     * @return teamBalance - The amount of AVAX owned by the contract but not needed.
     */
    function getTeamBalance() public view returns (uint256) {
        if (address(this).balance == 0) {
            return 0;
        }
        return address(this).balance - _getAvaxAmountOutForExactHatAmountIn(totalSupply() - balanceOf(address(this)));
    }

    /**
     * @notice Gets balance of HAT held by an account.
     * @param account - Account that you want to view balance for.
     * @return balanceOfAccount - the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view returns (uint256){
        return hatToken.balanceOf(account);
    }
    /**
     * @notice Gets total supply of HAT.
     * @return Returns the amount of HAT in existence.
     */
    function totalSupply() public view returns (uint256) {
        return hatToken.totalSupply();
    }

    /**
     * @notice Burns a given amount of HAT from sender's balance.
     */
    function burn(uint256 hatAmount) public {
        hatToken.burnFrom(_msgSender(), hatAmount);
    }

    /**
     * @notice Redeems 1 HAT.
     * @dev Sender needs at least 1 $HAT.
     */
    function redeemHat() public {
        hatToken.burnFrom(_msgSender(), 1e18);
        hatNft.mint(_msgSender());
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
