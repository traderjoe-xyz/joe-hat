// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20/extensions/ERC20Burnable.sol";

contract JoeHatToken is ERC20Burnable {
    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
     *
     * See {ERC20-constructor}.
     */
//    constructor(address owner) ERC20("Joe Hat Token", "HAT") {
    constructor() ERC20("Joe Hat Token", "HAT") {
        uint256 initialSupply = 150e18;
//        _mint(owner, initialSupply);
        _mint(_msgSender(), initialSupply);
    }
}