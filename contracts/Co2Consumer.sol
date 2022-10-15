// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Co2Consumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;    
    using Counters for Counters.Counter;
    
    //uint256 public s_co2e;
    //bool public test;
    
    Counters.Counter public s_roundID;
    bytes32 private jobId;
    uint256 private fee;

    struct Airline {
        uint256 id;
        string name;
    }

    struct Co2Emission {
        uint256 idAirline;
        uint256 roundId;
        uint256 co2Amount;
        uint256 startedAt;
        uint256 finishedAt;
        bytes32 requestId;
    }
    // ID Airline  -> (ID Record -> Co2Emission)
    mapping(uint256 => Co2Emission) s_EmissionHistory;

    event RequestCo2Emission(Co2Emission indexed co2Emission);
    
    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0x5CeD5FE184f6504DFF3Ce899392f8019f4F580f6);
        jobId = "5b11b78a00bc4151b44909421c04524e"; // insert right jobID
        fee = (1 * LINK_DIVISIBILITY) / 10;
    }

    function requestCo2Emission(
        uint256 _idAirline,
        string memory _from,
        string memory _to,
        string memory _passengers,
        string memory _classFlight
    ) public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId,address(this),this.fulfill.selector);
        s_roundID.increment();
        uint256 currentId = s_roundID.current();
        Co2Emission memory _co2 = Co2Emission(_idAirline, currentId, 0, block.timestamp, 0, 0);

        req.add("from", _from);
        req.add("to", _to);
        req.add("passengers", _passengers);
        req.add("classFlight", _classFlight);
        s_EmissionHistory[currentId] = _co2;
        return sendChainlinkRequest(req, fee);
    }


    function fulfill(bytes32 _requestId, uint256 _co2e) public recordChainlinkFulfillment(_requestId){
        //emit RequestCo2Emission(_requestId, _volume);
        uint256 currentId = s_roundID.current();
        Co2Emission memory _auxCo2 = s_EmissionHistory[currentId];
        require(_auxCo2.finishedAt == 0 && _auxCo2.requestId == 0, "Error fulfill");
        _auxCo2.co2Amount = _co2e;
        _auxCo2.requestId = _requestId;
        _auxCo2.finishedAt = block.timestamp;
        s_EmissionHistory[currentId] = _auxCo2;
        emit RequestCo2Emission(_auxCo2);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
