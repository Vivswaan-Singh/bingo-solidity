// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Game{

    struct player{
        uint256[5][5] box;
        bool[5][5] check;
    }

    struct game{
        uint256 startTime;
        address[] players;
        mapping(address => player) playerInfo;
        address[] winners;
        bool status;
    }
    
    address admin;
    uint256 public entryFees = 10;
    uint256 turnDuration=10;
    uint256 startDuration=10000000000000000000;
    uint256 gameNo;
    address coins;
    mapping(uint256 => game) games;

    error NotAdmin();
    error EntryFeeNotPaid();
    error JoiningTimeOver();
    error GameNoLongerActive();

    event newGame(uint256 gameNo); 
    event newPlayer(uint256[5][5] arr);
    event newPlay(uint256 col,uint256 val,bool win,uint256 inLoop);
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
        games[gameNo].status=true;
        emit newGame(gameNo);
        return gameNo;
    }

    function joinGame(uint256 gameNum) public returns(uint256[5][5] memory){
        require(games[gameNum].status,GameNoLongerActive());
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
        return games[gameNum].playerInfo[msg.sender].box;

    }

    function play(uint256 gameNum) public {
        require(games[gameNum].status,GameNoLongerActive());
        address[] memory players = games[gameNum].players;
        uint256 col = generateCol(gameNum);
        uint256 val = generateVal(gameNum, col);
        for(uint256 k=0;k<players.length;k++){
            for(uint256 i=0;i<5;i++){
                emit eqCheck(val, games[gameNum].playerInfo[players[k]].box[i][col]); 
                if(games[gameNum].playerInfo[players[k]].box[i][col]==val){
                    emit madeTrue();
                    games[gameNum].playerInfo[players[k]].check[i][col]=true;
                }
            }
            bool flag=checkBox(gameNum,players[k]);
            if(flag){
                ERC20(coins).transfer(players[k],entryFees*players.length);
                k=players.length+1;
                emit newPlay(col, val, flag, players.length);
                k=players.length+1;
                return ;
            }
        }
        emit newPlay(col, val, false, players.length);
    }

    function updateEntryFees(uint256 fees) public {
        require(msg.sender == admin, NotAdmin());
        entryFees = fees;
    }

    function updateturnDuration(uint256 duration) public {
        require(msg.sender == admin, NotAdmin());
        turnDuration = duration;
    }

    function updatestartDuration(uint256 duration) public {
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

    function checkBox(uint256 gameNum, address currPlayer) public returns(bool){
        bool[5][5] memory flag = games[gameNum].playerInfo[currPlayer].check;

        for(uint i=0;i<5;i++){
            bool flagRow= flag[i][0] && flag[i][1] && flag[i][2] && flag[i][3] && flag[i][4];
            if(flagRow){
                emit checker(flag);
                return true;
            }
        }

        for(uint i=0;i<5;i++){
            bool flagRow= flag[0][i] && flag[1][i] && flag[2][i] && flag[3][i] && flag[4][i];
            if(flagRow){
                emit checker(flag);
                return true;
            }
        }
        emit checker(flag);
        return false;
    }
}

contract Coins is ERC20 {
    constructor() ERC20("Coins", "CN") {}

    function mint(uint256 val) public {
        _mint(msg.sender, val);
    }
}

