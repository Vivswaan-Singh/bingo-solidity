// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Game is ReentrancyGuard{
    
    struct player{
        uint256[5][5] box;
        uint256 bitCheck;
    }

    enum GameStatus{
        DoesNotExist,
        NoPlayers,
        NotBeingPlayedYet,
        BeingPlayed,
        GameOver
    }

    struct game{
        uint256 startTime;
        address[] players;
        mapping(address => player) playerInfo;
        uint256 currPlayerInd;
        uint256 numOfRounds;
        address winner;
        GameStatus status;
    }
    
    address admin;
    uint256 entryFees = 10;
    uint256 turnDuration=100;
    uint256 startDuration=10000;
    uint256 gameNo;
    address coins;
    mapping(uint256 => game) games;

    error NotAdmin();
    error EntryFeeNotPaid();
    error JoiningTimeOver();
    error InvalidAddress();
    error GameNotActive(uint256 gameNum);
    error GameDoesNotExist(uint256 gameNum);
    error GameAlreadyBeingPlayed(uint256 gameNum);
    error GameNotStarted(uint256 gameNum);
    error GameOverAlready(uint256 gameNum);
    error NotYourTurn(address sender, address turn);


    event newGame(uint256 gameNo); 
    event newPlayer(uint256[5][5] arr);
    event newPlay(uint256 col,uint256 val,address winner);
    


    constructor(address _coins) {
        admin = msg.sender;
        coins=_coins;
        gameNo=0;
    }

    function startNewGame() public returns (uint256) {
        gameNo++;
        games[gameNo].startTime=block.timestamp;
        games[gameNo].status=GameStatus.NoPlayers;
        games[gameNo].currPlayerInd=0;
        games[gameNo].numOfRounds=0;
        emit newGame(gameNo);
        return gameNo;
    }

    function joinGame(uint256 gameNum) public nonReentrant returns(uint256[5][5] memory){
        require(msg.sender != address(0),InvalidAddress());
        require(games[gameNum].status != GameStatus.DoesNotExist,GameDoesNotExist(gameNum));
        require(games[gameNum].status != GameStatus.BeingPlayed,GameAlreadyBeingPlayed(gameNum));
        require(games[gameNum].status != GameStatus.GameOver,GameOverAlready(gameNum));
        require(block.timestamp<=games[gameNum].startTime+startDuration, JoiningTimeOver());
        bool received = ERC20(coins).transferFrom(msg.sender,address(this),entryFees);
        require(received, EntryFeeNotPaid());
        generateBox(msg.sender,gameNum);
        games[gameNum].players.push(msg.sender);
        games[gameNum].playerInfo[msg.sender].bitCheck = (1 << 12);

        emit newPlayer(games[gameNum].playerInfo[msg.sender].box);
        games[gameNum].status=GameStatus.NotBeingPlayedYet;
        return games[gameNum].playerInfo[msg.sender].box;

    }

    function play(uint256 gameNum) public nonReentrant returns(address) {
        require(games[gameNum].status!=GameStatus.DoesNotExist,GameDoesNotExist(gameNum));
        require(games[gameNum].status!=GameStatus.GameOver,GameOverAlready(gameNum));
        require(msg.sender==games[gameNum].players[games[gameNum].currPlayerInd], NotYourTurn(msg.sender, games[gameNum].players[games[gameNum].currPlayerInd]));
        games[gameNum].status=GameStatus.BeingPlayed;
        address[] memory players = games[gameNum].players;
        uint256 col = generateCol(gameNum);
        uint256 val = generateVal(gameNum, col);
        uint256 noOfPlayers = players.length;
        for(uint256 k=0;k<noOfPlayers;k++){
            for(uint256 i=0;i<5;i++){
                if(games[gameNum].playerInfo[players[k]].box[i][col]==val){
                    games[gameNum].playerInfo[players[k]].bitCheck |= (1 << ((i*5)+col));
                }
            }
            bool flag=checkBox(gameNum,players[k]);
            if(flag){
                games[gameNum].status=GameStatus.GameOver;
                ERC20(coins).transfer(players[k],entryFees*noOfPlayers);
                games[gameNum].winner=players[k];
                emit newPlay(col, val, players[k]); 
                return players[k]; 
            }
        }
        games[gameNum].numOfRounds+=1;
        games[gameNum].currPlayerInd+=1;
        games[gameNum].currPlayerInd%=noOfPlayers;
        emit newPlay(col, val, address(0));
        return address(0);
    }

    function updateEntryFees(uint256 fees) public {
        require(msg.sender == admin, NotAdmin());
        entryFees = fees;
    }

    function updateTurnDuration(uint256 duration) public {
        require(msg.sender == admin, NotAdmin());
        turnDuration = duration;
    }

    function updateStartDuration(uint256 duration) public {
        require(msg.sender == admin, NotAdmin());
        startDuration = duration;
    }

    function generateBox(address playerAddress, uint256 gameNum) public {
        uint256 seed = uint256(blockhash(block.number-1));
        uint256[5][5] memory arr;
        for(uint8 i = 0; i<5 ; i++){
            for(uint8 j=0; j<5; j++){
                if(!(i==2 && j==2)){
                    arr[i][j] = (uint256(keccak256((abi.encodePacked(seed,i,j,playerAddress,block.timestamp)))))%256;
                }
            }
        }
        games[gameNum].playerInfo[playerAddress].box=arr;
    }

    function generateCol(uint256 gameNum) public view returns(uint256) {
        uint256 seed = uint256(blockhash(block.number-1));
        return (uint256(keccak256(abi.encodePacked(seed,gameNum,msg.sender,block.timestamp))))%5;
    }

    function generateVal(uint256 gameNum, uint256 col) public view returns(uint256) {
        uint256 seed = uint256(blockhash(block.number-1));
        return (uint256(keccak256(abi.encodePacked(seed,gameNum,col,msg.sender,block.timestamp))))%256;
    }

    function checkBox(uint256 gameNum, address currPlayer) public view returns(bool){
        uint256 mask = games[gameNum].playerInfo[currPlayer].bitCheck;

        for(uint256 i=0;i<21;i+=5){
            uint256 rowMask = ((1 << i) | (1 << (i+1)) | (1 << (i+2)) | (1 << (i+3)) | (1 << (i+4)));
            uint256 flagRow= (mask & rowMask); 
            if(flagRow == rowMask){
                return true;
            }
        } 
        
        for(uint256 i=0;i<5;i++){
            uint256 colMask = ((1 << i) | (1 << (i+5)) | (1 << (i+10)) | (1 << (i+15)) | (1 << (i+20)));
            uint256 flagCol = (mask & colMask); 
            if(flagCol == colMask){
                return true;
            }
        }

        uint256 diag = ((1) | (1 << 6) | (1 << 12) | (1 << 18) | (1 << 24));

        if((mask & diag) == diag){
            return true;
        }

        uint256 revDiag = ((1 << 4) | (1 << 8) | (1 << 12) | (1 << 16) | (1 << 20));

        if((mask & revDiag) == revDiag){
            return true;
        }

        return false;
    }

    function getEntryFees() external view returns(uint256){
        return entryFees;
    }

    function getStartDuration() external view returns(uint256){
        return startDuration;
    }

    function getTurnDuration() external view returns(uint256){
        return turnDuration;
    }

    function getPlayers(uint256 gameNum) public view returns(address[] memory) {
        return games[gameNum].players;
    }

    function getWinner(uint256 gameNum) public view returns(address) {
        return games[gameNum].winner;
    }
}

contract Coins is ERC20 {
    constructor() ERC20("Coins", "CN") {}

    function mint(uint256 val) public {
        _mint(msg.sender, val);
    }
}

