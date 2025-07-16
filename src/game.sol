// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Game is ReentrancyGuard{
    
    struct player{
        uint256 boxNo;
        uint256 bitCheck;
        bool exists;
        uint256 playerId;   
        address playerAddress;
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
        uint256 currPlayerInd;
        uint256 fees; 
        uint256 startDuration;
        uint256 turnDuration;  
        address winner;
        uint256 lastMoveTime;
        GameStatus status;
        uint256 numOfPlayers; 
    }

    mapping(uint256 => mapping(uint256 => player)) playerInfo;
    
    address admin;
    uint256 entryFees = 10;
    uint256 turnDuration = 5;
    uint256 startDuration = 10;
    uint256 gameNo;
    uint256 immutable rootSeed;
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
    error WaitingForMorePlayers();
    error JoinTimeOver();
    error NotFirstPlayer();
    error NotJoined();


    event newGame(uint256 gameNo); 
    event newPlayer(uint256 boxNo);
    event newPlay(uint256 val);
    event updatedFees(uint256 fees);
    event updatedStartDuration(uint256 startDuration);
    event updatedTurnDuration(uint256 turnDuration);
    event winner(address winnerAddress, uint256 gameNo);

    constructor(address _coins, uint256 _rootSeed) {
        admin = msg.sender;
        rootSeed = _rootSeed;
        coins = _coins;
        gameNo = 0;
    }

    function startNewGame() public returns (uint256) {
        gameNo++;
        game memory currGame = games[gameNo];
        currGame.startTime = block.timestamp;
        currGame.lastMoveTime = block.timestamp + startDuration;
        currGame.status = GameStatus.NoPlayers;
        currGame.startDuration = startDuration;
        currGame.turnDuration = turnDuration;
        currGame.fees = entryFees;
        games[gameNo] = currGame;
        emit newGame(gameNo);
        return gameNo;
    }

    function joinGame(uint256 gameNum) public nonReentrant returns(uint256){
        game memory currGame = games[gameNum];
        uint256 playerInd = currGame.numOfPlayers;
        player memory currPlayer = playerInfo[gameNum][playerInd];

        require(msg.sender != address(0), InvalidAddress());
        require((gameNo != 0 && gameNum != 0 && gameNum<=gameNo && currGame.status != GameStatus.DoesNotExist), GameDoesNotExist(gameNum));
        require(block.timestamp <= currGame.startDuration + currGame.startTime, JoinTimeOver());  
        require(currGame.status != GameStatus.GameOver, GameOverAlready(gameNum));
        require(!existsInGame(gameNum, msg.sender), AlreadyJoined());
        
        bool received = ERC20(coins).transferFrom(msg.sender,address(this), currGame.fees);
        require(received, EntryFeeNotPaid());

        uint256 boxNum = generateBox(msg.sender, gameNum);
        currPlayer.boxNo = boxNum;
        currPlayer.bitCheck = 0; 
        currPlayer.exists = true;
        currPlayer.playerId = playerInd;
        currPlayer.playerAddress = msg.sender;
        playerInfo[gameNum][playerInd] = currPlayer;

        currGame.status = GameStatus.NotBeingPlayedYet;
        currGame.numOfPlayers++;

        games[gameNum] = currGame;

        emit newPlayer(boxNum);
        return boxNum;

    }

    function play(uint256 gameNum) public nonReentrant returns(address) {
        game memory currGame = games[gameNum];

        require(currGame.status != GameStatus.DoesNotExist, GameDoesNotExist(gameNum));
        require(currGame.status != GameStatus.GameOver, GameOverAlready(gameNum));
        require(block.timestamp > currGame.startTime + currGame.startDuration, WaitingForMorePlayers());
        require(existsInGame(gameNum, msg.sender), NotJoined());

        // require((currGame.status == GameStatus.NotBeingPlayedYet), TurnDurationOver());
        // if(currGame.status == GameStatus.NotBeingPlayedYet && msg.sender != currGame.players[currGame.currPlayerInd]){
        //     revert NotFirstPlayer(); 
        // }

        uint256 currentPlayerId = currGame.currPlayerInd;

        if(block.timestamp > currGame.lastMoveTime + currGame.turnDuration){
            currentPlayerId = (block.timestamp - (currGame.lastMoveTime + currGame.turnDuration))/currGame.turnDuration;
        }

        require(msg.sender == playerInfo[gameNum][currentPlayerId].playerAddress, NotYourTurn(msg.sender, playerInfo[gameNum][currentPlayerId].playerAddress));

        currGame.status = GameStatus.BeingPlayed;   
        uint256 val = generateVal(gameNum, msg.sender);
        uint256 noOfPlayers = currGame.numOfPlayers;

        for(uint256 k; k < noOfPlayers;){
            player memory temp = playerInfo[gameNum][k];
            address currPlayer = temp.playerAddress;
            uint256 boxNum = temp.boxNo;
            for(uint256 i; i < 25;){
                if((boxNum >> (i*9) & 511) == val){
                    temp.bitCheck |= (1 << (i));
                }
                unchecked {
                    i++;
                }
            }

            playerInfo[gameNum][k] = temp;
            uint256 score = checkBox(gameNum, k);

            if(score >= 5){
                currGame.status = GameStatus.GameOver;
                currGame.winner = currPlayer;
                games[gameNum] = currGame;
                bool sent = ERC20(coins).transfer(currPlayer, entryFees*noOfPlayers);
                require(sent, RewardNotPaid(currPlayer));
                emit winner(currPlayer, gameNum); 
                return currPlayer; 
            }

            unchecked {
                k++;
            }

        }

        currGame.currPlayerInd += 1;
        currGame.currPlayerInd %= noOfPlayers;
        currGame.lastMoveTime = block.timestamp;

        games[gameNum] = currGame;

        emit newPlay(val);
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

    function generateBox(address playerAddress, uint256 gameNum) internal view returns(uint256 boxNum) {
        uint256 seed = uint256(blockhash(block.number-1));

        for(uint8 i = 0; i<25;){
            uint256 temp = (uint256(keccak256((abi.encodePacked(seed, i, playerAddress, admin, block.timestamp, rootSeed, gameNum)))))%256;
            boxNum |= (temp << (i*9));

            unchecked {
                i++;
            }
        }

    }

    function generateVal(uint256 gameNum, address addr) internal view returns(uint256) {
        uint256 seed = uint256(blockhash(block.number-1));
        return ((uint256(keccak256(abi.encodePacked(seed, gameNum, addr, admin, rootSeed, block.timestamp))))%256);
    }

    function checkBox(uint256 gameNum, uint256 playerInd) internal view returns(uint256) {
        player memory currPlayer = playerInfo[gameNum][playerInd];
        uint256 mask = currPlayer.bitCheck;
        uint256 score;

        for(uint256 i; i < 21;){
            uint256 rowMask = ((1 << i) | (1 << (i+1)) | (1 << (i+2)) | (1 << (i+3)) | (1 << (i+4)));
            uint256 flagRow = (mask & rowMask); 
            if(flagRow == rowMask){
                unchecked {
                    score++;
                }
                if(score >= 5){
                    return score;
                }
            }

            unchecked {
                i += 5;
            }
        } 

        for(uint256 i; i < 5;){
            uint256 colMask = ((1 << i) | (1 << (i+5)) | (1 << (i+10)) | (1 << (i+15)) | (1 << (i+20)));
            uint256 flagCol = (mask & colMask); 
            if(flagCol == colMask){
                unchecked {
                    score++;
                }
                if(score >= 5){
                    return score;
                }
            }
            unchecked {
                i++;
            }
        }

        uint256 diag = ((1) | (1 << 6) | (1 << 12) | (1 << 18) | (1 << 24));

        if((mask & diag) == diag){
            unchecked {
                score++;
            }
            if(score >= 5){
                return score;
            }
        }

        uint256 revDiag = ((1 << 4) | (1 << 8) | (1 << 12) | (1 << 16) | (1 << 20));

        if((mask & revDiag) == revDiag){
            unchecked {
                score++;
            }
            if(score >= 5){
                return score;
            }
        }

        return score;
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


    function getWinner(uint256 gameNum) public view returns(address) {
        return games[gameNum].winner;
    }

    function existsInGame(uint256 gameNum, address playerAddr) internal view returns (bool) {
        uint256 len = games[gameNum].numOfPlayers;
        for(uint256 i; i < len;){
            if(playerInfo[gameNum][i].playerAddress == playerAddr){
                return true;
            }
            unchecked {
                i++;
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

