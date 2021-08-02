pragma solidity ^0.4.0;

contract GetPriceXYK {
    uint256 k = 15 * 30 * 30 * 1e18;  // change that to not be hard coded

    function swapExactAvaxForHat(uint256 avaxPooled, uint256 avaxAmount) public view returns(uint256) {
        return k * 1e18 / avaxPooled - k * 1e18/ (avaxPooled + avaxAmount);
    }

    function swapAvaxForExactHat(uint256 hatPooled, uint256 hatAmount) public view returns(uint256) {
        return k * 1e18 / (hatPooled - hatAmount) - k * 1e18 / hatPooled;
    }

    function swapExactHatForAvax(uint256 hatPooled, uint256 hatAmount) public view returns(uint256) {
        return k * 1e18 / hatPooled - k * 1e18 / (hatPooled + hatAmount);
    }

    function swapHatForExactAvax(uint256 avaxPooled, uint256 avaxAmount) public view returns(uint256) {
        return k * 1e18 / (avaxPooled - avaxAmount) - k * 1e18 / avaxPooled;
    }
}
