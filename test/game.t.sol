// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Game, Coins} from "../src/game.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CounterTest is Test {
    Game bingo;
    Coins coin;
    address gameAddress;
    address coinAddress;
    address addr1;
    address addr2;
    address addr3;
    address addr4;

    function setUp() public {
        coin = new Coins();
        coinAddress = address(coin);
        bingo = new Game(coinAddress);
        gameAddress = address(bingo);
        addr1 = address(1);
        addr2 = address(11);
        addr3 = address(121);
        addr4 = address(1331);
        vm.startPrank(addr1);
        Coins(coinAddress).mint(1000);
        ERC20(coinAddress).approve(gameAddress,500);
        vm.stopPrank();
        vm.startPrank(addr2);
        Coins(coinAddress).mint(1000);
        ERC20(coinAddress).approve(gameAddress,500);
        vm.stopPrank();
        vm.prank(addr3);
        Coins(coinAddress).mint(1000);
        ERC20(coinAddress).approve(gameAddress,500);
        vm.stopPrank();
        vm.prank(addr4);
        Coins(coinAddress).mint(1000);
        ERC20(coinAddress).approve(gameAddress,500);
        vm.stopPrank();
    }

    function test_play() public {
        uint gameInd = Game(gameAddress).startNewGame();
        vm.stopPrank();
        uint256 init_bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 init_bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 init_balGame=ERC20(coinAddress).balanceOf(gameAddress);
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        for(uint256 i=0;i<25;i++){
            vm.prank(addr3);
            Game(gameAddress).play(1);
        }
        uint256 bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 balGame=ERC20(coinAddress).balanceOf(gameAddress);
        assertEq(bal1+bal2+balGame, init_bal1+init_bal2+init_balGame);
    }

}
