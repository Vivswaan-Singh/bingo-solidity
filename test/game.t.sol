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
        vm.startPrank(addr3);
        Coins(coinAddress).mint(1000);
        ERC20(coinAddress).approve(gameAddress,500);
        vm.stopPrank();
        vm.startPrank(addr4);
        Coins(coinAddress).mint(1000);
        ERC20(coinAddress).approve(gameAddress,500);
        vm.stopPrank();
        vm.startPrank(addr5);
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


    function test_joinGameBeingPlayed() public {
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        uint256 startDuration = Game(gameAddress).getStartDuration();
        uint256 currTime = block.timestamp + startDuration + 1;
        vm.warp(currTime);
        vm.prank(addr1);
        Game(gameAddress).play(gameInd);
        vm.expectRevert(Game.JoinTimeOver.selector);
        vm.prank(addr5);
        Game(gameAddress).joinGame(gameInd);

    }

    function test_play(uint256 iters) public {
        vm.assume(iters>0 && iters<100);
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        uint256 init_bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 init_bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 init_balGame=ERC20(coinAddress).balanceOf(gameAddress);
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        uint256 startDuration = Game(gameAddress).getStartDuration();
        uint256 currTime = block.timestamp + startDuration + 1;
        address winner = address(0);
        for(uint256 i=0;i<iters;i++){
            vm.warp(currTime);
            vm.prank(addr1);
            winner = Game(gameAddress).play(gameInd); 
            if(winner == address(0)){
                vm.warp(currTime);
                vm.prank(addr2);
                Game(gameAddress).play(gameInd);
            }
            else{
                break;
            }
        }
        uint256 bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 balGame=ERC20(coinAddress).balanceOf(gameAddress);
        assertEq(bal1+bal2+balGame, init_bal1+init_bal2+init_balGame);
    }

    function test_playToWin() public {
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        uint256 init_bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 init_bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 init_balGame=ERC20(coinAddress).balanceOf(gameAddress);
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        address winner = address(0);
        uint256 cnt = 0;
        uint256 startDuration = Game(gameAddress).getStartDuration();
        uint256 currTime = block.timestamp + startDuration + 1;
        while(winner == address(0) && cnt < 1000){
            vm.warp(currTime);
            vm.prank(addr1);
            winner = (Game(gameAddress).play(gameInd));
            if(winner == address(0)){
                vm.warp(currTime);
                vm.prank(addr2);
                winner = (Game(gameAddress).play(gameInd));
            }
            else{
                break;
            }
            cnt++;
        }
        uint256 bal1=ERC20(coinAddress).balanceOf(addr1);
        uint256 bal2=ERC20(coinAddress).balanceOf(addr2);
        uint256 balGame=ERC20(coinAddress).balanceOf(gameAddress);
        assertEq(bal1+bal2+balGame, init_bal1+init_bal2+init_balGame);
    }

    function test_playWithoutTurn() public {
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        address winner = address(0);
        uint256 startDuration = Game(gameAddress).getStartDuration();
        uint256 currTime = block.timestamp + startDuration + 1;
        vm.warp(currTime);
        vm.prank(addr1);
        winner = (Game(gameAddress).play(gameInd));
        if(winner == address(0)){
            vm.expectRevert(abi.encodeWithSelector(Game.NotYourTurn.selector, addr1, addr2));
            vm.warp(currTime);
            vm.prank(addr1);
            winner = (Game(gameAddress).play(gameInd));
        }
    }
    
    function test_updateEntryFees(uint256 fee) public {
        vm.assume(fee>0 && fee<512);
        vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        Game(currGameAddress).updateEntryFees(fee);
        vm.stopPrank();
        assertEq(fee,currGame.getEntryFees());
    }

    function test_updateTurnDuration(uint256 duration) public {
        vm.assume(duration>0 && duration<512);
        vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        Game(currGameAddress).updateTurnDuration(duration);
        vm.stopPrank();
        assertEq(duration, currGame.getTurnDuration());
    }

    function test_updateStartDuration(uint256 duration) public {
        vm.assume(duration>0 && duration<512);
        vm.startPrank(addr1);
        Game currGame = new Game(coinAddress);
        address currGameAddress = address(currGame);
        Game(currGameAddress).updateStartDuration(duration);
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

    function test_getPlayers() public {
        vm.prank(addr5);
        uint256 gameInd = Game(gameAddress).startNewGame();
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr3);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr4);
        Game(gameAddress).joinGame(gameInd);
        address[] memory addrs = Game(gameAddress).getPlayers(gameInd);
        address[4] memory myAddrs = [addr1,addr2,addr3,addr4];
        for(uint8 i=0;i<4;i++){
            assertEq(addrs[i], myAddrs[i]);
        }
    }

    function test_getWinner() public {
        vm.prank(addr4);
        uint256 gameInd = Game(gameAddress).startNewGame();
        vm.prank(addr1);
        Game(gameAddress).joinGame(gameInd);
        vm.prank(addr2);
        Game(gameAddress).joinGame(gameInd);
        address winner = address(0);
        uint256 startDuration = Game(gameAddress).getStartDuration();
        uint256 currTime = block.timestamp + startDuration + 1;
        for(uint256 i=0;i<1000;i++){
            vm.warp(currTime);
            vm.prank(addr1);
            winner = (Game(gameAddress).play(gameInd));
            if(winner == address(0)){
                vm.warp(currTime);
                vm.prank(addr2);
                winner = (Game(gameAddress).play(gameInd));
            }
            else{
                break;
            }
        }
        assertEq(winner, Game(gameAddress).getWinner(gameInd));
        
    }

}
