// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Bingo Game Contract
/// @author Vivswaan Singh
/// @notice This contract implements a Bingo game, where players can join a game for a specific fees, receive a randomised board and then get reward if they win the game
/// @dev Uses bitmasking for checking win conditions and stores all board numbers in a packed uint256
contract Game is ReentrancyGuard{
    
    struct player{
        uint256 boxNo;
        uint256 bitCheck;
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
    mapping(uint256 => mapping(address => bool)) doesPlayerExist;
    
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


    /// @dev Emitted when a new game is created
    event newGame(uint256 gameNo); 

    /// @dev Emitted when a player joins a game
    event newPlayer(uint256 boxNo);

    /// @dev Emitted during a turn 
    event newPlay(uint256 val);

    /// @dev Emitted when admin updates the entry fees value for any future games
    event updatedFees(uint256 fees);

    /// @dev Emitted when admin updates the start duration value for any future games
    event updatedStartDuration(uint256 startDuration);

    /// @dev Emitted when admin updates the turn duration value for any future games
    event updatedTurnDuration(uint256 turnDuration);
    
    /// @dev Emitted when someone wins a game
    event winner(address winnerAddress, uint256 gameNo);

    /// @notice Initialises the Game contract
    /// @param _coins Address of ERC20 token to be used as fee and reward
    /// @param _rootSeed A root randomness seed used for board generation 
    constructor(address _coins, uint256 _rootSeed) {
        admin = msg.sender;
        rootSeed = _rootSeed;
        coins = _coins;
        gameNo = 0;
    }

    /// @notice Starts a new game instance and returns its Game ID
    /// @dev Game is initialised with default parameters and will allow players to join until startDuration
    /// @return gameNo The ID of the newly initialised game
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

    /// @notice Allows a player to join an open game by paying the required entry fees
    /// @param gameNum ID of the game player wants to join
    /// @return boxNum The 5x5 bingo board represented in a packed uint256 
    function joinGame(uint256 gameNum) public nonReentrant returns(uint256){
        game memory currGame = games[gameNum];
        uint256 playerInd = currGame.numOfPlayers;
        player memory currPlayer = playerInfo[gameNum][playerInd];

        require(msg.sender != address(0), InvalidAddress());
        require((gameNo != 0 && gameNum != 0 && gameNum<=gameNo && currGame.status != GameStatus.DoesNotExist), GameDoesNotExist(gameNum));
        require(block.timestamp <= currGame.startDuration + currGame.startTime, JoinTimeOver());  
        require(currGame.status != GameStatus.GameOver, GameOverAlready(gameNum));
        require(!doesPlayerExist[gameNum][msg.sender], AlreadyJoined());
        
        bool received = ERC20(coins).transferFrom(msg.sender,address(this), currGame.fees);
        require(received, EntryFeeNotPaid());

        uint256 boxNum = generateBox(msg.sender, gameNum);
        currPlayer.boxNo = boxNum;
        currPlayer.bitCheck = 0; 
        currPlayer.playerAddress = msg.sender;
        playerInfo[gameNum][playerInd] = currPlayer;

        currGame.status = GameStatus.NotBeingPlayedYet;
        currGame.numOfPlayers++;

        games[gameNum] = currGame;
        doesPlayerExist[gameNum][msg.sender] = true;

        emit newPlayer(boxNum);
        return boxNum;

    }

    /// @notice Allows the player to take a turn in a game they have joined
    /// @param gameNum ID of the game player wants to play
    /// @return winner Address of the winner or address(0) in case no one has won yet 
    function play(uint256 gameNum) public nonReentrant returns(address) {
        game memory currGame = games[gameNum];

        require(currGame.status != GameStatus.DoesNotExist, GameDoesNotExist(gameNum));
        require(currGame.status != GameStatus.GameOver, GameOverAlready(gameNum));
        require(block.timestamp > currGame.startTime + currGame.startDuration, WaitingForMorePlayers());
        require(doesPlayerExist[gameNum][msg.sender], NotJoined());

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

    /// @notice Updates the entry fees amount for any future games
    /// @param fees The new entry fees amount
    function updateEntryFees(uint256 fees) public {
        require(msg.sender == admin, NotAdmin());
        entryFees = fees;
        emit updatedFees(entryFees);
    }

    /// @notice Updates the turn duration for any future games
    /// @param duration The new turn duration value
    function updateTurnDuration(uint256 duration) public {
        require(msg.sender == admin, NotAdmin());
        turnDuration = duration;
        emit updatedTurnDuration(turnDuration);
    }

    /// @notice Updates the start duration for any future games
    /// @param duration The new start duration value
    function updateStartDuration(uint256 duration) public {
        require(msg.sender == admin, NotAdmin());
        startDuration = duration;
        emit updatedStartDuration(startDuration);
    }

    /// @dev Generates a pseudo random 5x5 bingo board using blockhash and keccak256
    /// @param playerAddress Address of the player
    /// @param gameNum ID of the game
    /// @return boxNum The 5x5 board stored in the form of a single uint256 by packing each number into 9 bits each
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

    /// @dev Generates a pseudo random value in the range 0-255 using blockhash and keccak256
    /// @param gameNum ID of the game
    /// @param addr Address of the player
    /// @return boxNum The 5x5 board stored in the form of a single uint256 by packing each number into 9 bits each
    function generateVal(uint256 gameNum, address addr) internal view returns(uint256) {
        uint256 seed = uint256(blockhash(block.number-1));
        return ((uint256(keccak256(abi.encodePacked(seed, gameNum, addr, admin, rootSeed, block.timestamp))))%256);
    }

    /// @dev Checks the player's bingo board for any completed rows, columns and diagonals
    /// @param gameNum ID of the game
    /// @param playerInd ID of the player
    /// @return score The number of filled lines on the bingo board i.e. bingo score
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

    /// @notice Returns the current entry fees
    /// @return entryFees The fees that needs to be paid to join a game
    function getEntryFees() external view returns(uint256){
        return entryFees;
    }

    /// @notice Returns the current start duration
    /// @return startDuration The time duration for which new players can join a game starting from its initialisation
    function getStartDuration() external view returns(uint256){
        return startDuration;
    }

    /// @notice Returns the current turn duration
    /// @return turnDuration The time duration of each player's turn 
    function getTurnDuration() external view returns(uint256){
        return turnDuration;
    }


    /// @notice Returns the winner for a specific game
    /// @param gameNum The ID of the game whose winner user wants to know
    /// @return winner The address of the winner or address(0) if no one has won yet 
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

