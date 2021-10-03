// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './JoeHatToken.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title Trader Joe's bonding curve contract for the $HAT token.
 * @notice Allows buying/selling of HATs to AVAX along a bonding curve.
 * @author LouisMeMyself
 */
contract JoeHatBondingCurve is Ownable {

    /// @notice Emitted when an owner seed the contract with amountAvax $AVAX and hatAmount $HAT.
    event SeedContract(address sender, uint256 avaxAmount, uint256 hatAmount);

    /// @notice Emitted swapping Avax for $HAT.
    event SwapAvaxForHat(uint256 avaxAmount, uint256 hatAmount);

    /// @notice Emitted swapping $HAT for Avax.
    event SwapHatForAvax(uint256 hatAmount, uint256 avaxAmount);

    /// @notice Emitted when an owner withdraw the tokens of the team balance.
    event TeamWithdraw(uint256 teamBalance);

    /// @notice a/b is between 0 and 1. During a sale, 1 - a/b is kept by the contract
    /// so that it can be retrieved by the team and to encourage people to HODL.
    uint256 public _a = 95;
    uint256 public _b = 100;

    /// @notice k the constant of the uniswap curve.
    uint256 public k;

    /// @notice Used to calculate the price of the very last token, because with uniswap
    /// you'll never be able to buy the very last token, as it diverges to infinity, (1/0)
    uint256 public lastHatPriceInAvax;

    /// @notice Max Supply of $HAT, when initialising, it's equal to the circulating supply.
    uint256 public maxSupply;

    /// @notice Keep a list of all the redeemers ordered by time. It will be used at some point...
    address[] public redeemers;

    /// @notice Used to calculate the amount of avax the contract needs to store
    /// It's equal to k / maxSupply, because there will never be more token than maxSupply.
    uint256 private reserveLowestAvax;

    JoeHatToken hatToken;


    /**
     * @notice Constructor of the contract, 
     * @param joeHatAddress - Address of the joeHatContract.
     * @param initialHatSupply - $HAT initial supply.
     * @param initialHatPrice - $HAT initial price in AVAX.
     */
    constructor(address joeHatAddress, uint256 initialHatSupply, uint256 initialHatPrice) {
        hatToken = JoeHatToken(joeHatAddress);

        /// @notice k = x*y = reserveHat * reserveAvax = initialHatSupply * (initialHatSupply * initialHatPrice).
        k = initialHatSupply * initialHatSupply * initialHatPrice / 1e36;


        /// @notice we calculate the reserveHat and reserveAvax as if all the tokens were
        /// owned by the smart contract.
        maxSupply = totalSupply();
        reserveLowestAvax = k * 1e18 / maxSupply;

        /// @notice we chose the last $HAT to be priced 4 times the price of the one before.
        lastHatPriceInAvax = k * 2;
    }

    /*** Public Hooks ***/

    /**
     * @notice Gets the reserveAvax if we were using a uniswap pool.
     * @return reserveAvax - The reserveAvax of that pool if it was a uniswap pool.
     */
    function getReserveAvax() public view returns (uint256) {
        uint256 balance = getReserveHat();
        if (balance == 0) {
            return 0;
        }

        uint256 reserveAvax;
        if (balance >= 1e18) {

            reserveAvax = k * 1e18 / balance;
        }
        else {
            /// calculate reserveAvax with lastHat function
            reserveAvax = k + _getAvaxAmountForLastExactHatAmount(1e18 - balance);
        }

//        require(address(this).balance >= reserveAvax - reserveLowestAvax, 'Critical Error, not enough AVAX');

        return reserveAvax;
    }

    /**
     * @notice Gets the reserveHat if we were using a uniswap pool.
     * @return reserveHat - The reserveHat of that pool if it was a uniswap pool.
     */
    function getReserveHat() public view returns (uint256) {
        return balanceOf(address(this));
    }

    /**
     * @notice Sells a given amount of AVAX for $HAT.
     * @param minHatAmount - The min amount of $HAT to be received.
     */
    function swapExactAvaxForHat(uint256 minHatAmount) external payable {
        uint256 hatAmount = getHatAmountOutForExactAvaxAmountIn(msg.value);

        require(hatAmount >= minHatAmount, 'Front ran');

        hatToken.transfer(_msgSender(), hatAmount);

        emit SwapAvaxForHat(msg.value, hatAmount);
    }

    /**
     * @notice Buys a given amount of $HAT for $AVAX.
     * @param exactHatAmount - The exact amount of $HAT.
     */
    function swapAvaxForExactHat(uint256 exactHatAmount) external payable {
        uint256 avaxAmount = getAvaxAmountInForExactHatAmountOut(exactHatAmount);

        require(avaxAmount <= msg.value, "Front ran");

        uint256 avaxLeftover = msg.value - avaxAmount;

        /// Transfers hatAmount $HAT to the sender.
        hatToken.transfer(_msgSender(), exactHatAmount);
        /// Transfers surplus $AVAX to _msgSender().
        (bool success,) = _msgSender().call{value: avaxLeftover}("");
        require(success, "Transfer failed");

        emit SwapAvaxForHat(avaxAmount, exactHatAmount);
    }

    /**
     * @notice Sells a given amount of $HAT for AVAX with fees deducted.
     * @param exactHatAmount - The amount of $HAT to swap for AVAX.
     * @param minAvaxAmount - The min amount of AVAX to be received.
     */
    function swapExactHatForAvaxWithFees(uint256 exactHatAmount, uint256 minAvaxAmount) external {
        /// Amount that is sent to the _msgSender, approx equal to avaxAmount*a/b.
        uint256 avaxAmountWithFees = getAvaxAmountOutForExactHatAmountInWithFees(exactHatAmount);

        require(avaxAmountWithFees >= minAvaxAmount, 'Front ran');

        /// Transfer hatAmount $HAT to the contract.
        hatToken.transferFrom(_msgSender(), address(this), exactHatAmount);
        /// Transfer avaxAmountWithFees $AVAX to the _msgSender().
        (bool success,) = _msgSender().call{value: avaxAmountWithFees}("");
        require(success, "Transfer failed");

        emit SwapHatForAvax(exactHatAmount, avaxAmountWithFees);
    }

    /**
     * @notice Buys a given amount of $AVAX for $HAT with fees deducted.
     * @param exactAvaxAmount - The exact amount of $AVAX to be received.
     * @param maxHatAmount - The max amount of $HAT to be sold.
     */
    function swapHatForExactAvaxWithFees(uint256 exactAvaxAmount, uint256 maxHatAmount) external {
        /// Amount that is sent to the _msgSender, approx equal to avaxAmount*a/b.
        uint256 hatAmount = getHatAmountInForExactAvaxAmountOutWithFees(exactAvaxAmount);

        require(hatAmount <= maxHatAmount, 'Front ran');

        /// Transfer hatAmount $HAT to the contract.
        hatToken.transferFrom(_msgSender(), address(this), hatAmount);
        /// Transfer avaxAmountWithFees $AVAX to the _msgSender().
        (bool success,) = _msgSender().call{value: exactAvaxAmount}("");
        require(success, "Transfer failed");

        emit SwapHatForAvax(hatAmount, exactAvaxAmount);
    }

    /**
     * @notice Calculates the amount of $HAT received if a given amount of AVAX is sold.
     * @param avaxAmount - The amount of AVAX sold.
     * @return hatAmount - The amount of $HAT received.
     */
    function getHatAmountOutForExactAvaxAmountIn(uint256 avaxAmount) public view returns (uint256) {
        uint256 reserveAvax = getReserveAvax();
        require(reserveAvax + avaxAmount <= k + lastHatPriceInAvax, 'getHatAmountOutForExactAvaxAmountIn: Not enough $HAT in reserve');
        /// this is added for the VERY last $HAT
        /// This tests if when user buy that amount he will be buying at least a bit of the last $HAT
        /// it needs to check this because the last $HAT doesn't use the same function
        if (reserveAvax + avaxAmount > k) {
            uint256 hatAmountOld = 0;
            uint256 avaxAmountOld = 0;
            /// This tests if the `sender` will buy some hats before the last one,
            /// if so it needs to get the price of the previous ones independently
            if (reserveAvax < k) {
                avaxAmountOld = k - reserveAvax;
                hatAmountOld = getReserveHat() - 1e18;
            }
            uint256 hatAmountNew = _getLastHatAmountForExactAvaxAmount(avaxAmount - avaxAmountOld);
            return hatAmountOld + hatAmountNew;
        }
        return k * 1e18 / reserveAvax - k * 1e18 / (reserveAvax + avaxAmount);
    }

    /**
     * @notice Calculates the required amount of AVAX to buy a given amount of $HAT.
     * @param hatAmount - The amount of $HAT to buy.
     * @return avaxAmount - The amount of AVAX required.
     */
    function getAvaxAmountInForExactHatAmountOut(uint256 hatAmount) public view returns (uint256) {
        uint256 reserveHat = getReserveHat();
        require(reserveHat >= hatAmount, 'getAvaxAmountInForExactHatAmountOut: Not enough $HAT in reserve');
        /// this is added for the VERY last $HAT
        /// This tests if when user buy that amount he will be buying at least a bit of the last $HAT
        /// it needs to check this because the last $HAT doesn't use the same function
        if (reserveHat - hatAmount < 1e18) {
            uint256 avaxAmountOld = 0;
            uint256 hatAmountOld = 0;
            /// This tests if the `sender` will buy some hats before the last one,
            /// if so it needs to get the price of the previous ones independently
            if (reserveHat > 1e18) {
                hatAmountOld = reserveHat - 1e18;
                avaxAmountOld = k - getReserveAvax();
            }
            uint256 avaxAmountNew = _getAvaxAmountForLastExactHatAmount(hatAmount - hatAmountOld);
            return avaxAmountOld + avaxAmountNew;
        }
        return k * 1e18 / (reserveHat - hatAmount) - k * 1e18 / reserveHat;
    }

    /**
     * @notice Calculates the received amount of AVAX if a given amount of $HAT is sold with fees
     * deducted.
     * @param hatAmount - The amount of $HAT to sell.
     * @return avaxAmount - The amount of AVAX received.
     */
    function getAvaxAmountOutForExactHatAmountInWithFees(uint256 hatAmount) public view returns (uint256) {
        require(getReserveHat() + hatAmount <= maxSupply, 'getAvaxAmountOutForExactHatAmountInWithFees: Not enough $HAT');
        return _getAvaxAmountOutForExactHatAmountIn(hatAmount * _a / _b);
    }

    /**
     * @notice Calculates the required amount of $HAT to buy a given amount of AVAX with fees
     * taken into account.
     * @param avaxAmount - The amount of AVAX to buy.
     * @return hatAmount - The amount of $HAT required.
     */
    function getHatAmountInForExactAvaxAmountOutWithFees(uint256 avaxAmount) public view returns (uint256) {
        uint256 hatAmountWithFees = _getHatAmountInForExactAvaxAmountOut(avaxAmount * _b / _a);
        require(getReserveHat() + hatAmountWithFees <= maxSupply, 'getHatAmountInForExactAvaxAmountOutWithFees: Not enough $HAT');
        return hatAmountWithFees;
    }


    /*** Private hooks ***/

    /**
     * @notice Calculates the amount of AVAX received if a given amount of $HAT is sold.
     * @dev This is a helper function used in swapExactHatForAvaxWithFees and 
     * getAvaxAmountOutForExactHatAmountInWithFees.
     * @param hatAmount - The amount of $HAT to sell.
     * @return avaxAmount - The amount of AVAX received.
     */
    function _getAvaxAmountOutForExactHatAmountIn(uint256 hatAmount) private view returns (uint256) {
        uint256 reserveHat = getReserveHat();
        /// this is added for the VERY last $HAT
        /// This tests if when user buy that amount he will be buying at least a bit of the last $HAT
        /// it needs to check this because the last $HAT doesn't use the same function
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
     * @notice Calculates the received amount of AVAX for a given amount of $HAT sold before the last $HAT.
     * @dev This is a helper function used in _getAvaxAmountOutForExactHatAmountIn.
     * @param hatAmount - The amount of $HAT to sell.
     * @return avaxAmount - The amount of AVAX received.
     */
    function _getAvaxAmountOutForExactHatAmountInBeforeLastHat(uint256 hatAmount) private view returns (uint256) {
        return k - k * 1e18 / (1e18 + hatAmount);
    }

    /**
     * @notice Calculates amount of AVAX received for given amount of the last $HAT.
     * @dev This is a helper function used in getAvaxAmountInForExactHatAmountOut and 
     * _getAvaxAmountOutForExactHatAmountIn.
     * @param hatAmount - The amount of last $HAT to swap for AVAX.
     * @return avaxAmount - The amount of AVAX received.
     */
    function _getAvaxAmountForLastExactHatAmount(uint256 hatAmount) private view returns (uint256) {
        return lastHatPriceInAvax * hatAmount / 1e18;
    }

    /**
     * @notice Calculates the required amount of $HAT to buy a given an amount of AVAX.
     * @dev This is a helper function used in getHatAmountInForExactAvaxAmountOutWithFees.
     * @param avaxAmount - The amount of AVAX to buy.
     * @return hatAmount - The amount of $HAT required.
     */
    function _getHatAmountInForExactAvaxAmountOut(uint256 avaxAmount) private view returns (uint256) {
        uint256 reserveAvax = getReserveAvax();
        require(reserveAvax >= avaxAmount, 'Not enough $AVAX in the pool');
        /// this is added for the VERY last $HAT
        /// This tests if when user buy that amount he will be buying at least a bit of the last $HAT
        /// it needs to check this because the last $HAT doesn't use the same function
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
     * @notice Calculates the required amount of $HAT to buy a given amount of AVAX before 
     * the last $HAT.
     * @dev This is a helper function used in _getHatAmountInForExactAvaxAmountOut.
     * @param avaxAmount - The amount of AVAX to buy.
     * @return hatAmount - The amount of $HAT required.
     */
    function _getHatAmountInForExactAvaxAmountOutBeforeLastHat(uint256 avaxAmount) private view returns (uint256) {
        return k * 1e18 / (k - avaxAmount) - 1e18;
    }

    /**
     * @notice Calculates amount of last $HAT received for a given amount of AVAX.
     * @dev This is a helper function used in getHatAmountOutForExactAvaxAmountIn and 
     * _getHatAmountInForExactAvaxAmountOut.
     * @param avaxAmount - The AVAX amount to swap for the last $HAT.
     * @return lastHatAmount - The amount of the last $HAT received.
     */
    function _getLastHatAmountForExactAvaxAmount(uint256 avaxAmount) private view returns (uint256) {
        return avaxAmount * 1e18 / lastHatPriceInAvax;
    }


    /*** Admin functions ***/

    /**
     * @notice Adds $AVAX and $HAT to the contract.
     * @dev IMPORTANT : this needs to be called to seed the contract, you shouldn't send tokens directly
     * to the contract. You need to approve the token's contract, with at least the value you'll send to
     * the contract, which is: k * 1e18 / (avaxAmount + k * 1e18 / maxSupply)).
     */
    function seedContract() external payable onlyOwner {
        /// We require this orelse we should use the price of the lastHat and this is too complicated
        require(msg.value <= k, 'You need to add less $AVAX, so the contracts owns more than 1 $HAT');
        uint256 hatAmount = k * 1e18 / (msg.value + k * 1e18 / maxSupply);
        hatToken.transferFrom(_msgSender(), address(this), hatAmount);
        emit SeedContract(_msgSender(), msg.value, hatAmount);
    }

    /**
     * @notice Withdraws the team funds, which is equal to the amount of AVAX kept by 
     * the contract that aren't needed if everyone sells their tokens.
     */
    function withdrawTeamBalance() public onlyOwner {
        uint256 teamBalance = getTeamBalance();

        (bool success, ) = owner().call{value:teamBalance}("");
        require(success, "Withdraw team balance failed");

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
        uint256 contractBalance = address(this).balance;
        if (contractBalance < _getAvaxAmountOutForExactHatAmountIn(totalSupply() - balanceOf(address(this)))) {
            return 0;
        }
        return contractBalance - _getAvaxAmountOutForExactHatAmountIn(totalSupply() - balanceOf(address(this)));
    }

    /**
     * @notice Gets balance of $HAT held by an account.
     * @param account - Account that you want to view balance for.
     * @return balanceOfAccount - the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view returns (uint256){
        return hatToken.balanceOf(account);
    }

    /**
     * @notice Gets total supply of $HAT.
     * @return Returns the amount of $HAT in existence.
     */
    function totalSupply() public view returns (uint256) {
        return hatToken.totalSupply();
    }

    /**
     * @notice Burns a given amount of $HAT from sender's balance.
     */
    function burn(uint256 hatAmount) public {
        hatToken.burnFrom(_msgSender(), hatAmount);
    }

    /**
     * @notice Redeems 1 $HAT.
     * @dev Sender needs at least 1 $HAT.
     */
    function redeemHat() public {
        hatToken.burnFrom(_msgSender(), 1e18);
        redeemers.push(_msgSender());
    }
}
