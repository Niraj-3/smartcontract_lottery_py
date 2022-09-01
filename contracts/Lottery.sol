//SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable{
    
    address payable[] players;
    AggregatorV3Interface internal ethUsdPriceFeed;
    address payable public recentWinner;
    uint256 public usdEntryFee;
    bytes32 public keyHash;
    uint256 public fee;
    uint256 public randomness;
    
    enum LOTTERY_STATE{
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lottery_state;
    event RequestedRandomness(bytes32 requestId);

    constructor(address _priceFeedAddress,
    address _vrfCoordinator, 
    address _link,
    uint256 _fee,
    bytes32 _keyHash
    ) 
        public VRFConsumerBase(_vrfCoordinator,_link)
    {
        usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        fee = _fee;
        keyHash = _keyHash;
    }


    function enter() payable public{
        //$50 minimum
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value>=getEntranceFee(),"Not Enough ETH!");
        players.push(msg.sender);
    }

    function getEntranceFee() public view returns(uint256){
        (,int price,,,) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10;
        uint256 costToEnter = (usdEntryFee* 10**18)/adjustedPrice;
        return costToEnter;
    }
    function startLottery() public onlyOwner{
        require(lottery_state==LOTTERY_STATE.CLOSED, "Can't open a new lottery yet!!");
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner{
        // uint256(
        //     keccack256(
        //         abi.encodePacked(
        //             nonce, // nonce is preditable (aka, transaction number)
        //             msg.sender, // msg.sender is predictable
        //             block.difficulty, // can actually be manipulated by the miners!
        //             block.timestamp // timestamp is predictable
        //         )
        //     )
        // ) % players.length;
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyHash,fee);
        emit RequestedRandomness(requestId);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override{
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't there yet!"
        );
        require(_randomness > 0, "random-not-found");
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance);
        // Reset
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomness = _randomness;
    }
}
