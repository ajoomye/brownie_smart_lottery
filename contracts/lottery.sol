// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Lottery is VRFConsumerBaseV2, Ownable {

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    address vrfCoordinator;
    bytes32 keyHash;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint256 requestId;
   

    address payable[] public players;
    uint256 public usdEntryFee;
    AggregatorV3Interface public priceFeed;

    enum LOTTERY_STATE{OPEN, CLOSED, CALCULATING_WINNER}

    LOTTERY_STATE public lottery_state;

    constructor(address _priceFeed, uint64 _subscriptionId, address _vrfCoordinator, bytes32 _keyHash) public VRFConsumerBaseV2(vrfCoordinator) {
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = _subscriptionId;

        usdEntryFee = 50 * (10**18);
        priceFeed = AggregatorV3Interface(_priceFeed);
        lottery_state = LOTTERY_STATE.CLOSED;
    }

    function enter() public payable {
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Not Enough!");
        players.push(payable(msg.sender));


    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256  adjustedPrice = uint256(price) * 10**10; // 18 decimals 

        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(lottery_state == LOTTERY_STATE.CLOSED, "Cannot start lottery");
        lottery_state = LOTTERY_STATE.OPEN;
    }

    

    function endLottery() public onlyOwner {
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;

        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
         
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "Not in calculating winner state");
        uint256 winnerIndex = randomWords[0] % players.length;
        address payable winner = players[winnerIndex];
        winner.transfer(address(this).balance);

        // Reset lottery
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
    }



}