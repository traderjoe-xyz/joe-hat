// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract JoeHatToken is ERC20Burnable {
    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
     *
     * See {ERC20-constructor}.
     */
    constructor() ERC20("Joe Hat Token", "HAT") {
        uint256 initialSupply = 150e18;
        _mint(_msgSender(), initialSupply);
    }
    
    function mint(uint256 value) public {
        _mint(_msgSender(), value);
    }
}