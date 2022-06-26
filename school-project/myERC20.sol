// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/ERC20/Ownable.sol";

contract myERC20 is ERC20, Ownable {
    mapping(address=> bool) admins;

    constructor() ERC20("My name", "TST") {}

    function mint(address _to, uint _amount) external {
        require(admins[msg.sender], "Cannot mint, not admin");
        _mint(_to, _amount);
    }

    function adAdmin(address _admin)

}