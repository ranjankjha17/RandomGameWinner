//SPDX-License-Identifier:MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RandomWinnerGame is VRFConsumerBase, Ownable{
    
    //The amount of Link to send with the request
    uint256 public fee;
    //ID of public key against which randomness is generated
    bytes32 public keyHash;

    //Address of the players
    address[] public players;
    //Maxnumber of players in one game
    uint8 maxPlayers;
    //Variable to indicate if the game has started or not
    bool public gameStarted;
    //the fees for entering the game
    uint256 entryFee;
    //current game id
    uint256 public gameId;

    //emitted when the game starts
    event GameStarted(uint256 gameId, uint8 maxPlayers,uint256 entryFee);
    //emitted when  someone joins a game
    event PlayerJoined(uint256 gameId, address player);
    //emitted when the game ends
    event GameEnded(uint256 gameId,address winner,bytes32 requestId);

    constructor(address vrfCoordinator,address linkToken,bytes32 vrfKeyHash,uint256 vrfFee) 
    VRFConsumerBase(vrfCoordinator,linkToken){
        keyHash=vrfKeyHash;
        fee=vrfFee;
        gameStarted=false;
    }

    function startGame(uint8 _maxPlayers,uint256 _entryFee) public onlyOwner{
        require(!gameStarted,"Game is currently running");

        //empty the players array
        delete players;

        maxPlayers=_maxPlayers;

        gameStarted=true;

        entryFee=_entryFee;

        gameId +=1;

        emit GameStarted(gameId, maxPlayers, entryFee);
    }


    function joinGame() public payable{
        require(gameStarted,"Game has not been started yet.");

        require(msg.value == entryFee,"Value sent is not equal to entryFee");

        require(players.length < maxPlayers,"Game is full");

        players.push(msg.sender);

        emit PlayerJoined(gameId, msg.sender);

        if(players.length == maxPlayers){
            getRandomWinner();
        }
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal virtual override  {
        
        uint256 winnerIndex=randomness % players.length;
        
        address winner=players[winnerIndex];

        (bool sent,)=winner.call{value:address(this).balance}("");

        require(sent,"Failed to send Ether");

        emit GameEnded(gameId, winner, requestId);

        gameStarted=false;
    }

    function getRandomWinner() private returns (bytes32 requestId){

        require(LINK.balanceOf(address(this)) >= fee,"Not enough LINK");

        return requestRandomness(keyHash, fee);
    }

    receive() external payable{}

    fallback() external payable{}

}