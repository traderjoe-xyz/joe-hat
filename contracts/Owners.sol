// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Owners {
    mapping(address => bool) public _isOwner;
    address[] private _owners;
    
    constructor(){
        _isOwner[msg.sender] = true;
        _owners.push(msg.sender);
    }
    
    function addOwner(address newOwner) public onlyOwners{
        require(!_isOwner[newOwner], "Address is already an owner!");
        _isOwner[newOwner] = true;
        _owners.push(newOwner);
    }
    
    function removeOwner(address removedOwner) public onlyOwners{
        require(_isOwner[removedOwner], "Address isn't an owner!");
        uint256 lenOwner = _owners.length-1;
        require(lenOwner >= 0, "Contract needs at least 1 owner");
        address[] memory newOwners = new address[](lenOwner);
        uint256 j;
        unchecked{
            for (uint256 i = 0; i <= lenOwner; i++) {
                j++;
                if (_owners[i] == removedOwner) {
                    j++;
                }
                else {
                    newOwners[i] = _owners[j - 1];
                }
            }
        }
        _owners = newOwners;
        _isOwner[removedOwner] = false;
        emit RemovedOwner(removedOwner);
    }

    modifier onlyOwners() {
        require(_isOwner[msg.sender] == true, "Owners: caller is not an owner");
        _;
    }
    
    function getOwners() public view returns (address[] memory){
        return _owners;
    }
    
    
    event RemovedOwner(address removedOwner);
}