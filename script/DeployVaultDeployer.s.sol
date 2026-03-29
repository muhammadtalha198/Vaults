// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {VaultDeployer} from "../src/VaultDeployer.sol";

contract DeployVaultDeployer is Script {
    function run() external returns (VaultDeployer deployer) {
        address authorizedContract = vm.envAddress("AUTHORIZED_CONTRACT");

        vm.startBroadcast();
        deployer = new VaultDeployer(authorizedContract);
        vm.stopBroadcast();

        console.log("VaultDeployer deployed at:", address(deployer));
    }
}
