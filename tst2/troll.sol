// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract ethNftCollection{

    string github = "https://github.com/TeddyNotBear/eth-nft-collection";

    function getOurGithub() public view returns(string memory) {
        return  github;
    }
}