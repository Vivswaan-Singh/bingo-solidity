// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Game is ReentrancyGuard{
    
    struct player{
        uint256[5][5] box; // use bit manipulation instead
        uint256 bitCheck;
        uint256 score;
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
        uint256 currPlayerInd;
        uint256 fees; 
        uint256 startDuration;
        uint256 turnDuration;  
        address winner;
        uint256 lastMoveTime;
        GameStatus status;
        uint256 numOfPlayers; 
    }

    mapping(uint256=>mapping(address => player)) playerInfo;
    
    address admin;
    uint256 entryFees = 0;
    uint256 turnDuration=0;
    uint256 startDuration=10;
    uint256 gameNo;
    address coins;
    mapping(uint256 => game) games;

    error NotAdmin();
    error EntryFeeNotPaid();
    error InvalidAddress();
    error GameNotActive(uint256 gameNum);
    error GameDoesNotExist(uint256 gameNum);
    error GameAlreadyBeingPlayed(uint256 gameNum);
    error GameNotStarted(uint256 gameNum);
    error GameOverAlready(uint256 gameNum);
    error NotYourTurn(address sender, address turn);
    error TurnDurationOver();
    error RewardNotPaid(address winner);
    error AlreadyJoined();
    error WaitingForMorePlayers(uint256 time,uint256 neededTime);
    error JoinTimeOver();


    event newGame(uint256 gameNo); 
    event newPlayer(uint256[5][5] arr);
    event newPlay(uint256 val,address winner);
    event updatedFees(uint256 fees);
    event updatedStartDuration(uint256 startDuration);
    event updatedTurnDuration(uint256 turnDuration);
    


    constructor(address _coins) {
        admin = msg.sender;
        coins=_coins;
        gameNo=0;
    }

    function startNewGame() public returns (uint256) {
        gameNo++;
        game memory currGame = games[gameNo];
        currGame.startTime=block.timestamp;
        currGame.lastMoveTime=block.timestamp;
        currGame.status=GameStatus.NoPlayers;
        currGame.startDuration = startDuration;
        currGame.turnDuration = turnDuration;
        currGame.fees = entryFees;
        currGame.winner = address(0);
        games[gameNo] = currGame;
        emit newGame(gameNo);
        return gameNo;
    }

    function joinGame(uint256 gameNum) public nonReentrant returns(uint256[5][5] memory){
        game memory currGame = games[gameNum];
        require(msg.sender != address(0), InvalidAddress());
        require((gameNo != 0 || gameNum != 0 || currGame.status == GameStatus.DoesNotExist),GameDoesNotExist(gameNum));
        require(block.timestamp <= currGame.startDuration + currGame.startTime, JoinTimeOver());  
        require(currGame.status != GameStatus.GameOver,GameOverAlready(gameNum));
        require(!existsInGame(gameNum, msg.sender), AlreadyJoined());
        
        bool received = ERC20(coins).transferFrom(msg.sender,address(this),currGame.fees);
        require(received, EntryFeeNotPaid());
        generateBox(msg.sender,gameNum);
        playerInfo[gameNum][msg.sender].bitCheck = 0; 
        currGame.lastMoveTime = block.timestamp;
        currGame.status = GameStatus.NotBeingPlayedYet;
        currGame.numOfPlayers++;

        games[gameNum] = currGame;
        games[gameNum].players.push(msg.sender);

        emit newPlayer(playerInfo[gameNum][msg.sender].box);
        return playerInfo[gameNum][msg.sender].box;

    }

    function play(uint256 gameNum) public nonReentrant returns(address) {
        game memory currGame = games[gameNum];
        require(currGame.status != GameStatus.DoesNotExist, GameDoesNotExist(gameNum));
        require(currGame.status != GameStatus.GameOver, GameOverAlready(gameNum));
        require(block.timestamp > currGame.startTime + currGame.startDuration, WaitingForMorePlayers(block.timestamp, currGame.startTime + currGame.startDuration));
        require((currGame.status == GameStatus.NotBeingPlayedYet || block.timestamp <= currGame.lastMoveTime + currGame.turnDuration), TurnDurationOver());
        require(msg.sender == currGame.players[currGame.currPlayerInd], NotYourTurn(msg.sender, currGame.players[currGame.currPlayerInd]));

        currGame.status = GameStatus.BeingPlayed;   // remove keep logic in join instead 
        address[] memory players = currGame.players;
        uint256 val = generateVal(gameNum, msg.sender);
        uint256 noOfPlayers = currGame.numOfPlayers;

        for(uint256 k=0;k<noOfPlayers;k++){
            player memory temp = playerInfo[gameNum][players[k]];

            for(uint256 i=0;i<5;i++){
                for(uint256 j=0;j<5;j++){
                    if(temp.box[i][j] == val){
                        temp.bitCheck |= (1 << ((i*5)+j));
                    }
                } 
            }

            playerInfo[gameNum][players[k]] = temp;
            checkBox(gameNum,players[k]);

            if(temp.score >= 5){
                currGame.status = GameStatus.GameOver;
                currGame.winner = players[k];
                games[gameNum] = currGame;
                bool sent = ERC20(coins).transfer(players[k], entryFees*noOfPlayers);
                require(sent, RewardNotPaid(players[k]));
                emit newPlay(val, players[k]); // diff event
                return players[k]; 
            }

        }

        currGame.currPlayerInd += 1;
        currGame.currPlayerInd %= noOfPlayers;
        currGame.lastMoveTime = block.timestamp;

        games[gameNum] = currGame;

        emit newPlay(val, address(0));
        return address(0);
    }

    function updateEntryFees(uint256 fees) public {
        require(msg.sender == admin, NotAdmin());
        entryFees = fees;
        emit updatedFees(entryFees);
    }

    function updateTurnDuration(uint256 duration) public {
        require(msg.sender == admin, NotAdmin());
        turnDuration = duration;
        emit updatedTurnDuration(turnDuration);
    }

    function updateStartDuration(uint256 duration) public {
        require(msg.sender == admin, NotAdmin());
        startDuration = duration;
        emit updatedStartDuration(startDuration);
    }

    function generateBox(address playerAddress, uint256 gameNum) internal {
        uint256 seed = uint256(blockhash(block.number-1));
        uint256[5][5] memory arr;

        for(uint8 i = 0; i<5 ; i++){
            for(uint8 j=0; j < 5; j++){
                arr[i][j] = (uint256(keccak256((abi.encodePacked(seed,i,j,playerAddress,block.timestamp)))))%256;
            }
        }

        playerInfo[gameNum][playerAddress].box=arr;
    }

    function generateVal(uint256 gameNum, address addr) internal view returns(uint256) {
        uint256 seed = uint256(blockhash(block.number-1));
        return (uint256(keccak256(abi.encodePacked(seed,gameNum,addr,msg.sender,block.timestamp))))%256;
    }

    function checkBox(uint256 gameNum, address playerAddress) internal {
        player memory currPlayer = playerInfo[gameNum][playerAddress];
        uint256 mask = currPlayer.bitCheck;

        for(uint256 i = 0; i < 21; i += 5){

            uint256 rowMask = ((1 << i) | (1 << (i+1)) | (1 << (i+2)) | (1 << (i+3)) | (1 << (i+4)));
            uint256 flagRow = (mask & rowMask); 
            if(flagRow == rowMask){
                currPlayer.score++;
                if(currPlayer.score >= 5){
                    playerInfo[gameNum][playerAddress] = currPlayer;
                    return ;
                }
            }
        } 

        for(uint256 i = 0; i < 5; i++){
            uint256 colMask = ((1 << i) | (1 << (i+5)) | (1 << (i+10)) | (1 << (i+15)) | (1 << (i+20)));
            uint256 flagCol = (mask & colMask); 
            if(flagCol == colMask){
                currPlayer.score++;
                if(currPlayer.score >= 5){
                    playerInfo[gameNum][playerAddress] = currPlayer;
                    return ;
                }
            }
        }

        uint256 diag = ((1) | (1 << 6) | (1 << 12) | (1 << 18) | (1 << 24));

        if((mask & diag) == diag){
            currPlayer.score++;
            if(currPlayer.score >= 5){
                playerInfo[gameNum][playerAddress] = currPlayer;
                return ;
            }
        }

        uint256 revDiag = ((1 << 4) | (1 << 8) | (1 << 12) | (1 << 16) | (1 << 20));

        if((mask & revDiag) == revDiag){
            currPlayer.score++;
            if(currPlayer.score >= 5){
                playerInfo[gameNum][playerAddress] = currPlayer;
                return ;
            }
        }
        playerInfo[gameNum][playerAddress] = currPlayer;
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

    function existsInGame(uint256 gameNum, address playerAddr) internal view returns (bool) {
        address[] memory players = getPlayers(gameNum);
        for(uint256 i = 0; i < players.length; i++){
            if(players[i] == playerAddr){
                return true;
            }
        }
        return false;
    }
}

contract Coins is ERC20 {
    constructor() ERC20("Coins", "CN") {}

    function mint(uint256 val) public {
        _mint(msg.sender, val);
    }
}

