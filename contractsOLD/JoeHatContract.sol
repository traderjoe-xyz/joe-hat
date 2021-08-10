// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Owners.sol";
import "./JoeHatToken.sol";

contract JoeHatContract is Owners, Context{
    uint256 public _a = 95;
    uint256 public _b = 100;
    uint256 public k;
    uint256 public reserveAvax;
    uint256 public reserveHat;
    JoeHatToken hatContract;
    
    
    constructor(address joeHatAddress, uint256 init_supply, uint256 init_price) {
        hatContract = JoeHatToken(joeHatAddress);
        k = init_supply * init_supply * init_price * 1e18;
        reserveHat = totalSupply();
        reserveAvax = k * 1e18 / totalSupply();
    }
    
    function setRatio(uint256 a, uint256 b) public {
        require(_b >= _a, "b needs to be greater or equal than a");
        _a = a;
        _b = b;
        emit SetRatio(_a, _b);
    }
    
    function addHat(uint256 hatAdded, uint256 avaxRemoved) private {
        require (reserveHat + hatAdded <= totalSupply(), "Too much hat added");
        reserveHat += hatAdded;
        reserveAvax -= avaxRemoved;
    }
    
    function removeHat(uint256 hatRemoved, uint256 avaxAdded) private {
        reserveHat -= hatRemoved;
        reserveAvax += avaxAdded;
    }
    
    function seedAvax() external payable onlyOwners {
        removeHat(getExactAvaxForHat(msg.value), msg.value);
        emit SeedAvax(_msgSender(), msg.value);
    }
    
    function swapAvaxForHat(uint256 avaxAmount, uint256 hatAmount) private {
        hatContract.approve(_msgSender(), hatAmount);
        hatContract.transfer(_msgSender(), hatAmount);
        
        removeHat(hatAmount, msg.value);
        
        emit SwapAvaxForHat(avaxAmount, hatAmount);
    }
    
    function swapExactAvaxForHat() external payable returns (bool) {
        uint256 hatAmount = getExactAvaxForHat(msg.value);
        
        swapAvaxForHat(msg.value, hatAmount);
        
        return true;
    }

    function swapAvaxForExactHat(uint256 hatAmount) external payable returns (bool) {
        uint256 avaxAmount = getAvaxForExactHat(hatAmount);
        require(avaxAmount == msg.value, "avaxAmount is wrong");
        
        swapAvaxForHat(msg.value, hatAmount);
        
        return true;
    }

    function swapExactHatForAvaxWithFees(uint256 hatAmount) external returns (bool) {
        uint256 avaxAmount = _getExactHatForAvax(hatAmount);
        uint256 avaxAmountWithFees = avaxAmount * _a / _b;
        uint256 hatAmountWithFees = hatAmount * _a / _b;
        
        hatContract.transferFrom(_msgSender(), address(this), hatAmountWithFees);
        hatContract.burnFrom(_msgSender(), hatAmount - hatAmountWithFees);
        payable(_msgSender()).transfer(avaxAmountWithFees);
        
        addHat(hatAmountWithFees, avaxAmountWithFees);
        
        emit SwapHatForAvax(hatAmount, avaxAmountWithFees);
        return true;
    }

    function swapHatForExactAvaxWithFees(uint256 avaxAmount) external returns (bool) {
        uint256 hatAmount = _getHatForExactAvax(avaxAmount);
        uint256 hatAmountWithFees = hatAmount * (_b + 1) / _a;
        require(hatAmountWithFees >= balanceOf(_msgSender()), "ERC20: swapped HAT amount exceeds balance");
        
        hatContract.transferFrom(_msgSender(), address(this), hatAmount);
        hatContract.burnFrom(_msgSender(), hatAmountWithFees - hatAmount);
        payable(_msgSender()).transfer(avaxAmount);
        
        addHat(hatAmount, avaxAmount);
        
        emit SwapHatForAvax(hatAmount, avaxAmount);
        return true;
    }
    

    function getExactAvaxForHat(uint256 avaxAmount) public view returns (uint256) {
        return k * 1e18 / reserveAvax - k * 1e18 / (reserveAvax + avaxAmount);
    }

    function getAvaxForExactHat(uint256 hatAmount) public view returns (uint256) {
        return k * 1e18 / (reserveHat - hatAmount) - k * 1e18 / reserveHat;
    }

    function getHatForExactAvaxWithFees(uint256 avaxAmount) public view returns (uint256) {
        return _getHatForExactAvax(avaxAmount) * (_b + 1) / _a;
    }

    function getExactHatForAvaxWithFees(uint256 hatAmount) public view returns (uint256) {
        return _getExactHatForAvax(hatAmount) * _a / _b;
    }

    function _getHatForExactAvax(uint256 avaxAmount) private view returns (uint256) {
        return (k * 1e18 / (reserveAvax - avaxAmount) - k * 1e18 / reserveAvax);
    }

    function _getExactHatForAvax(uint256 hatAmount) private view returns (uint256) {
        return (k * 1e18 / reserveHat - k * 1e18 / (reserveHat + hatAmount));
    }
    
    function teamWithdraw() public onlyOwners {
        uint256 teamBalance = getWithdrawableByTeam();
        payable(_msgSender()).transfer(teamBalance);
        emit TeamWithdrawal(teamBalance);
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
    
    event SeedAvax(address sender, uint256 valueAVAX);
    event GetNewHat(uint256 oldBalance);
    event SetRatio(uint256 a, uint256 b);
    event SwapAvaxForHat(uint256 avaxAmount, uint256 hatAmount);
    event SwapHatForAvax(uint256 hatAmount, uint256 avaxAmount);
    event TeamWithdrawal(uint256 teamBalance);
}