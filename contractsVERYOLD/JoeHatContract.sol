// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./GetPriceXYK.sol";
import "./ERC20.sol";

contract JoeHatContract is ERC20 {
    uint256 public _a = 95;
    uint256 public _b = 100;

    uint256 public leftOver = 0;

    constructor() ERC20("HAT", "Joe Hat Token"){
        require(_a < _b);
        uint256 initialSupply = 150e18;
        _mint(address(this), initialSupply);
    }

    function getAddress() public view returns (address){
        return address(this);
    }

    receive() external payable {
        uint256 value = getPurchaseReturn(msg.value);
        transferFrom(address(this), msg.sender, value);
        emit Received(msg.sender, getPurchaseReturn(msg.value));
    }


    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        if (sender != address(this)){
            super.transferFrom(sender, recipient, amount);
        }
        else {
            _transfer(sender, recipient, amount);
        }
        return true;
    }

    uint256 k = 15 * 30 * 30 * 1e18;  // change that to not be hard coded

    function swapExactAvaxForHat(uint256 avaxPooled, uint256 avaxAmount) public {
        return k / avaxPooled * 1e18 - k / (avaxPooled + avaxAmount) * 1e18;
    }

    function swapAvaxForExactHat(uint256 hatPooled, uint256 hatAmount) public {
        return k / (hatPooled - hatAmount) * 1e18 - k / hatPooled * 1e18;
    }

    function swapExactHatForAvax(uint256 hatPooled, uint256 hatAmount) public {
        return k / hatPooled * 1e18 - k / (hatPooled + hatAmount) * 1e18;
    }

    function swapHatForExactAvax(uint256 avaxPooled, uint256 avaxAmount) public {
        return k / (avaxPooled - avaxAmount) * 1e18 - k / avaxPooled * 1e18;
    }

    function sell(uint256 amountToken) public {
        uint256 value = amountToken * _a / _b;
        uint256 toBurn = amountToken - value;

        transferFrom(msg.sender, address(this), value);
        _burn(msg.sender, toBurn);

        payable(msg.sender).transfer(getSellReturn(value));
        leftOver += getSellReturn(toBurn);
    }

    function getPurchaseReturn(uint256 buyAmount) public view returns (uint256) {
        return buyAmount / 2;
    }

    function getSellReturn(uint256 sellAmount) public view returns (uint256) {
        return sellAmount * 2;
    }

    function redeemHat() public {
        _burn(msg.sender, 1e18);
        leftOver += getSellReturn(1e18);
    }

    function withdrawLeftOver() public {
        payable(msg.sender).transfer(leftOver);
        leftOver = 0;
    }

    event Received(address, uint);
}