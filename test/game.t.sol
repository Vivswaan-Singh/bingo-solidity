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
    address addr5;

    event Log(uint256 iter);

    function setUp() public {
        coin = new Coins();
        coinAddress = address(coin);
        bingo = new Game(coinAddress);
        gameAddress = address(bingo);
        addr1 = address(1);
        addr2 = address(11);
        addr3 = address(121);
        addr4 = address(1331);
        addr5 = address(11111);
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

    function test_startNewGame(uint256 n) public {
        vm.assume(n>0 && n<256);
        uint256 sum = 0;
        for(uint256 i=0;i<n;i++){
            sum += Game(gameAddress).startNewGame();
        }
        assertEq(sum,(n*(n+1))/2);
    }

    function test_joinGameNotExisting() public {
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        vm.expectRevert(abi.encodeWithSelector(Game.GameDoesNotExist.selector, gameInd+1));
        vm.prank(addr4);
        Game(gameAddress).joinGame(gameInd+1);
    }

    function test_joinGameBeingPlayed() public {
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr1);
        Game(gameAddress).play(gameInd);
        vm.expectRevert(abi.encodeWithSelector(Game.GameAlreadyBeingPlayed.selector, gameInd));
        vm.prank(addr5);
        Game(gameAddress).joinGame(gameInd);

    }

    function test_play() public {
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        uint256 init_bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 init_bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 init_balGame=ERC20(coinAddress).balanceOf(gameAddress);
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        for(uint256 i=0;i<25;i++){
            vm.prank(addr1);
            Game(gameAddress).play(gameInd);
            vm.prank(addr2);
            Game(gameAddress).play(gameInd);
        }
        uint256 bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 balGame=ERC20(coinAddress).balanceOf(gameAddress);
        assertEq(bal1+bal2+balGame, init_bal1+init_bal2+init_balGame);
    }

    function test_playToWin() private {
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        uint256 init_bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 init_bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 init_balGame=ERC20(coinAddress).balanceOf(gameAddress);
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        bool flag = true;
        uint256 i=1;
        while(flag){
            vm.prank(addr1);
            flag = !(Game(gameAddress).play(gameInd));
            vm.prank(addr2);
            flag = !(Game(gameAddress).play(gameInd));
            emit Log(i++);
        }
        uint256 bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 balGame=ERC20(coinAddress).balanceOf(gameAddress);
        assertEq(bal1+bal2+balGame, init_bal1+init_bal2+init_balGame);
    }
    
    function test_updateEntryFees(uint256 fee) public {
        vm.assume(fee>0 && fee<512);
        //vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        Game(currGameAddress).updateEntryFees(fee);
        //vm.stopPrank();
        assertEq(fee,currGame.getEntryFees());
    }

    function test_updateTurnDuration(uint256 duration) public {
        vm.assume(duration>0 && duration<512);
        vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        Game(currGameAddress).updateTurnDuration(duration);
        vm.stopPrank();
        assertEq(duration,currGame.getTurnDuration());
    }

    function test_updateStartDuration(uint256 duration) public {
        vm.assume(duration>0 && duration<512);
        vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        Game(currGameAddress).updateStartDuration(duration);(duration);
        vm.stopPrank();
        assertEq(duration,currGame.getStartDuration());
    }

    function test_updateEntryFees_fail(uint256 fee) public {
        vm.assume(fee>0 && fee<512);
        vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        vm.stopPrank();
        vm.expectRevert(Game.NotAdmin.selector);
        vm.prank(addr2);
        Game(currGameAddress).updateEntryFees(fee);
        
    }

    function test_updateTurnDuration_fail(uint256 duration) public {
        vm.assume(duration>0 && duration<512);
        vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        vm.stopPrank();
        vm.expectRevert(Game.NotAdmin.selector);
        vm.prank(addr2);
        Game(currGameAddress).updateTurnDuration(duration);
    }

    function test_updateStartDuration_fail(uint256 duration) public {
        vm.assume(duration>0 && duration<512);
        vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        vm.stopPrank();
        vm.expectRevert(Game.NotAdmin.selector);
        vm.prank(addr2);
        Game(currGameAddress).updateStartDuration(duration);(duration);
    }

}
