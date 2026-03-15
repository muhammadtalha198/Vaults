// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PublicPoolVault} from "../src/PublicPoolVault.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract DeployPublicPoolVault is Script {
    function run() external returns (PublicPoolVault vault) {
        address multisig = vm.envAddress("MULTISIG_ADDRESS");
        address token = vm.envAddress("TOKEN_ADDRESS");

        vm.startBroadcast();
        vault = new PublicPoolVault(multisig, token);
        vm.stopBroadcast();

        console.log("PublicPoolVault deployed at:", address(vault));
    }
}
