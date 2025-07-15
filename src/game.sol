// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Game is ReentrancyGuard{
    
    struct player{
        uint256[5][5] box;
        bool[5][5] check;
    }

    struct game{
        uint256 startTime;
        address[] players;
        mapping(address => player) playerInfo;
        uint256 currPlayerInd;
        address[] winners;
        address winner;
        uint256 status;
    }
    
    address admin;
    uint256 entryFees = 10;
    uint256 turnDuration=10;
    uint256 startDuration=10000000000000000000;
    uint256 gameNo;
    address coins;
    mapping(uint256 => game) games;

    error NotAdmin();
    error EntryFeeNotPaid();
    error JoiningTimeOver();
    error GameNotActive(uint256 gameNum);
    error GameDoesNotExist(uint256 gameNum);
    error GameAlreadyBeingPlayed(uint256 gameNum);
    error GameNotStarted(uint256 gameNum);
    error GameOverAlready(uint256 gameNum);
    error NotYourTurn();


    event newGame(uint256 gameNo); 
    event newPlayer(uint256[5][5] arr);
    event newPlay(uint256 col,uint256 val,bool win);
    event checker(bool[5][5] flag);
    event madeTrue(); 
    event eqCheck(uint256 val, uint256 arrVal);
    


    constructor(address _coins) {
        admin = msg.sender;
        coins=_coins;
        gameNo=0;
    }

    function startNewGame() public returns (uint256) {
        gameNo++;
        games[gameNo].startTime=block.timestamp;
        games[gameNo].status=1;
        games[gameNo].currPlayerInd=0;
        emit newGame(gameNo);
        return gameNo;
    }

    function joinGame(uint256 gameNum) public nonReentrant returns(uint256[5][5] memory){
        require(games[gameNum].status!=0,GameDoesNotExist(gameNum));
        require(games[gameNum].status!=2,GameAlreadyBeingPlayed(gameNum));
        require(games[gameNum].status!=3,GameOverAlready(gameNum));
        require(block.timestamp<=games[gameNum].startTime+startDuration, JoiningTimeOver());
        bool received = ERC20(coins).transferFrom(msg.sender,address(this),entryFees);
        require(received, EntryFeeNotPaid());
        generateBox(msg.sender,gameNum);
        games[gameNum].players.push(msg.sender);
        games[gameNum].playerInfo[msg.sender].check=[[false,false,false,false,false],
                                                    [false,false,false,false,false],
                                                    [false,false,true,false,false],
                                                    [false,false,false,false,false],
                                                    [false,false,false,false,false]
                                                ];
        

        emit newPlayer(games[gameNum].playerInfo[msg.sender].box);
        games[gameNum].status=1;
        return games[gameNum].playerInfo[msg.sender].box;

    }

    function play(uint256 gameNum) public nonReentrant returns(bool) {
        require(games[gameNum].status!=0,GameDoesNotExist(gameNum));
        require(games[gameNum].status!=3,GameOverAlready(gameNum));
        require(msg.sender==games[gameNum].players[games[gameNum].currPlayerInd], NotYourTurn());
        games[gameNum].status=2;
        address[] memory players = games[gameNum].players;
        uint256 col = generateCol(gameNum);
        uint256 val = generateVal(gameNum, col);
        uint256 noOfPlayers = players.length;
        for(uint256 k=0;k<noOfPlayers;k++){
            for(uint256 i=0;i<5;i++){
                if(games[gameNum].playerInfo[players[k]].box[i][col]==val){
                    games[gameNum].playerInfo[players[k]].check[i][col]=true;
                }
            }
            bool flag=checkBox(gameNum,players[k]);
            if(flag){
                games[gameNum].winner=players[k];
                games[gameNum].status=3;
                ERC20(coins).transfer(players[k],entryFees*noOfPlayers);
                k=players.length+1;
                emit newPlay(col, val, flag);
                return flag;
            }
        }
        games[gameNo].currPlayerInd+=1;
        games[gameNo].currPlayerInd%=noOfPlayers;
        emit newPlay(col, val, false);
        return false;
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
        bool[5][5] memory flag = games[gameNum].playerInfo[currPlayer].check;

        for(uint i=0;i<5;i++){
            bool flagRow= flag[i][0] && flag[i][1] && flag[i][2] && flag[i][3] && flag[i][4];
            if(flagRow){
                return true;
            }
        }

        for(uint i=0;i<5;i++){
            bool flagRow= flag[0][i] && flag[1][i] && flag[2][i] && flag[3][i] && flag[4][i];
            if(flagRow){
                return true;
            }
        }

        if(flag[0][0] && flag[1][1] && flag[3][3] && flag[4][4]){
            return true;
        }

        if(flag[0][4] && flag[1][3] && flag[3][1] && flag[4][0]){
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
}

contract Coins is ERC20 {
    constructor() ERC20("Coins", "CN") {}

    function mint(uint256 val) public {
        _mint(msg.sender, val);
    }
}

