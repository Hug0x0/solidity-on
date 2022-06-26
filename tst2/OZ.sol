// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract GameItems is ERC1155 {
    uint256 public constant GOLD = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant THORS_HAMMER = 2;
    uint256 public constant SWORD = 3;

    constructor() ERC1155("https://game.example/api/item/{id}.json") {
        _mint(msg.sender, GOLD, 100, "");
        _mint(msg.sender, SILVER, 100, "");
        _mint(msg.sender, THORS_HAMMER, 100, "");
        _mint(msg.sender, SWORD, 100, "");
    }
}