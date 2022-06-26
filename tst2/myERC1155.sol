// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract myERC1155 is ERC1155, Ownable {
    mapping(address => bool) admins;

    constructor() ERC1155("Test", "TsT") {}

    function mint(address _to, uint _amount) external {
        require(admins[msg.sender], "not able to mint");
        _mint(_to, _amount);
    }

    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) external onlyOwner {
        admins[_admin] = false;
    }
}