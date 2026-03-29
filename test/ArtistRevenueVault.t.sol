// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ArtistRevenueVault} from "../src/ArtistRevenueVault.sol";

contract ArtistRevenueVaultTest is Test {
    ERC20Mock internal usdc;
    ArtistRevenueVault internal vault;

    address internal artist = address(0xA11CE);
    address internal stranger = address(0xBEEF);

    function setUp() public {
        usdc = new ERC20Mock();
        vault = new ArtistRevenueVault(address(usdc), artist);

        usdc.mint(stranger, 1_000_000e18);
        vm.prank(stranger);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_deposit_tracks_totalReceived() public {
        vm.prank(stranger);
        vault.deposit(100e18);
        assertEq(vault.totalReceived(), 100e18);
        assertEq(vault.vaultBalance(), 100e18);
    }

    function test_artist_can_release() public {
        vm.prank(stranger);
        vault.deposit(500e18);

        address recipient = address(0xC0FFEE);
        vm.prank(artist);
        vault.release(recipient, 200e18);

        assertEq(usdc.balanceOf(recipient), 200e18);
        assertEq(vault.totalReleased(), 200e18);
        assertEq(vault.vaultBalance(), 300e18);
    }

    function test_nonArtist_cannot_release() public {
        vm.prank(stranger);
        vault.deposit(100e18);

        vm.prank(stranger);
        vm.expectRevert(ArtistRevenueVault.NotArtist.selector);
        vault.release(stranger, 1e18);
    }

    function test_cannot_overWithdraw() public {
        vm.prank(stranger);
        vault.deposit(50e18);

        vm.prank(artist);
        vm.expectRevert(ArtistRevenueVault.InsufficientBalance.selector);
        vault.release(artist, 51e18);
    }
}
